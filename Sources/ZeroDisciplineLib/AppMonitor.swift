import Foundation
import AppKit

/// Status of a monitored application
public class MonitoredAppStatus {
    public var lastUsed: Date
    public let appPath: String
    private let config: ZeroDisciplineConfig

    public init(lastUsed: Date, appPath: String, config: ZeroDisciplineConfig) {
        self.lastUsed = lastUsed
        self.appPath = appPath
        self.config = config
    }
    
    public func timeInactive() -> TimeInterval {
        return Date().timeIntervalSince(lastUsed)
    }

    public func remainingTime() -> Int {
        let inactive = timeInactive()
        return max(0, config.inactivityDelay - Int(inactive))
    }

    public func shouldBeKilled() -> Bool {
        return isRunning() && timeInactive() >= Double(config.inactivityDelay)
    }


    public func isRunning() -> Bool {
        return findRunningApp() != nil
    }

    public func displayName() -> String {
        if let app = findRunningApp(),
           let name = app.localizedName {
            return name
        }
        return URL(fileURLWithPath: appPath).lastPathComponent.replacingOccurrences(of: ".app", with: "")
    }

    public func findRunningApp() -> NSRunningApplication? {
        let workspace = NSWorkspace.shared
        return workspace.runningApplications.first { app in
            guard let bundleURL = app.bundleURL, !app.isHidden else { return false }
            return bundleURL.path == appPath
        }
    }

    /// Get lastUsed date using max of current date and app launch date
    public func getLastUsedWithLaunchDate() -> Date {
        let currentDate = Date()
        guard let runningApp = findRunningApp(),
              let launchDate = runningApp.launchDate else {
            print("🔍 \(displayName()): No running app found or no launchDate, using currentDate")
            return currentDate
        }
        
        let age = currentDate.timeIntervalSince(launchDate)
        print("🔍 \(displayName()): Found PID=\(runningApp.processIdentifier), launchDate=\(launchDate), age=\(Int(age))s")
        
        let result = max(currentDate, launchDate)
        print("🔍 \(displayName()): Using \(result == currentDate ? "currentDate" : "launchDate") as lastUsed")
        return result
    }

    /// Find all processes related to this app (main + extensions/services)
    public func findRelatedProcesses() -> [NSRunningApplication] {
        let appName = URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent
        let allApps = NSWorkspace.shared.runningApplications
        
        return allApps.filter { app in
            guard let bundleURL = app.bundleURL else { return false }
            let bundlePath = bundleURL.path
            
            // Include if bundle path contains our app name or is inside our app bundle
            return bundlePath.hasPrefix(appPath) || 
                   bundlePath.contains(appName)
        }
    }
}

/// Main application monitoring service
@MainActor
public class AppMonitor: ObservableObject {
    @Published public var monitoredApps: [MonitoredAppStatus] = []

    private let config: ZeroDisciplineConfig
    private var monitorTimer: Timer?
    private var lastLoggedTopN: String = ""

    public init(config: ZeroDisciplineConfig) {
        self.config = config

        print("🎯 Zero Discipline started - monitoring \(config.appPaths.count) apps")
        print("⏰ Settings: \(config.inactivityDelay)s inactivity delay, keep top \(config.topN) apps in-use")

        let currentDate = Date()
        for appPath in config.appPaths {
            let appStatus = MonitoredAppStatus(
                lastUsed: currentDate,
                appPath: appPath,
                config: config
            )
            appStatus.lastUsed = appStatus.getLastUsedWithLaunchDate()
            monitoredApps.append(appStatus)
        }
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                self.runMonitoringCycle()
            }
        }
    }

    // Note: Timer cleanup handled by ARC


    // MARK: - Private Methods


    private func runMonitoringCycle() {
        let topNApps = getTopNApps()

        let topNNames = topNApps.compactMap { path in
            URL(fileURLWithPath: path).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        }
        if !topNNames.isEmpty {
            let topNString = topNNames.joined(separator: ", ")
            if topNString != lastLoggedTopN {
                print("👀 Apps in use: \(topNString)")
                lastLoggedTopN = topNString
            }
        } else if !lastLoggedTopN.isEmpty {
            lastLoggedTopN = ""
        }

        for app in monitoredApps {
            if topNApps.contains(app.appPath) {
                app.lastUsed = app.getLastUsedWithLaunchDate()
            }
        }

        for app in monitoredApps {
            if app.shouldBeKilled() {
                print("📊 App status before kill: \(app.displayName()) - lastUsed: \(app.lastUsed), timeInactive: \(app.timeInactive())s, shouldBeKilled: \(app.shouldBeKilled())")
                quitApp(app: app)
            }
        }
        let countdownSummary = monitoredApps.compactMap { app -> String? in
            if !app.shouldBeKilled() && app.timeInactive() > 1.0 && app.isRunning() {
                return "\(app.displayName()): \(app.remainingTime())s"
            }
            return nil
        }.joined(separator: ", ")

        if !countdownSummary.isEmpty {
            print("⏱️ Countdown: \(countdownSummary)")
        }

        // Force UI update - @Published doesn't detect changes inside class objects
        objectWillChange.send()
    }


    private func getTopNApps() -> [String] {
        // Modern NSWorkspace approach - clean and simple
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
            .filter { app in
                guard app.activationPolicy == .regular,
                      !app.isHidden,
                      app.bundleURL != nil else { return false }
                return true
            }
            .sorted { app1, app2 in
                // Sort by PID as proxy for launch order (newer apps have higher PIDs)
                return app1.processIdentifier > app2.processIdentifier
            }
            .prefix(config.topN)
            .compactMap { $0.bundleURL?.path }
        
        return Array(runningApps)
    }




    @discardableResult
    private func quitApp(app: MonitoredAppStatus) -> Bool {
        let relatedProcesses = app.findRelatedProcesses()
        guard !relatedProcesses.isEmpty else {
            print("⚠️ App \(app.displayName()) not found or not running")
            return false
        }

        let appName = app.displayName()
        print("🎯 Terminating \(appName) (\(relatedProcesses.count) processes)")
        
        // Try graceful termination first on main processes
        var mainProcesses = relatedProcesses.filter { $0.activationPolicy == .regular }
        if mainProcesses.isEmpty {
            mainProcesses = [relatedProcesses.first!] // At least one process
        }
        
        var allTerminated = true
        for process in mainProcesses {
            let success = process.terminate()
            if !success {
                print("⚠️ Failed to terminate process \(process.processIdentifier)")
                allTerminated = false
            }
        }

        // Wait for graceful termination (shorter timeout since we kill all processes)
        let gracePeriod: TimeInterval = 2.0
        let startTime = Date()
        
        if allTerminated {
            print("✅ Graceful termination initiated, waiting for cleanup...")
            
            while Date().timeIntervalSince(startTime) < gracePeriod {
                let remainingProcesses = app.findRelatedProcesses()
                if remainingProcesses.isEmpty {
                    print("✅ \(appName) fully terminated after \(String(format: "%.1f", Date().timeIntervalSince(startTime)))s")
                    return true
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        
        // Force terminate any remaining processes
        let stubornProcesses = app.findRelatedProcesses()
        if !stubornProcesses.isEmpty {
            print("💥 \(appName) has \(stubornProcesses.count) stubborn processes, force terminating...")
            
            for process in stubornProcesses {
                let forceSuccess = process.forceTerminate()
                if forceSuccess {
                    print("✅ Force terminated PID \(process.processIdentifier)")
                } else {
                    print("⚠️ Failed to force terminate PID \(process.processIdentifier)")
                }
            }
            
            // Final check after force termination
            Thread.sleep(forTimeInterval: 0.5)
            let finalProcesses = app.findRelatedProcesses()
            if finalProcesses.isEmpty {
                print("✅ \(appName) force terminated after \(String(format: "%.1f", Date().timeIntervalSince(startTime)))s total")
                return true
            } else {
                print("⚠️ \(appName) still has \(finalProcesses.count) unkillable processes")
                return false
            }
        }
        
        print("⚠️ \(appName) couldn't be terminated, giving up")
        return false
    }
}

// MARK: - Extensions for status display in UI
extension MonitoredAppStatus {
    public func displayText(inactivityDelay: Int) -> String {
        if !isRunning() {
            return "not running"
        } else {
            if timeInactive() < 1.0 {
                return "in use"
            } else {
                return "\(remainingTime())s remaining"
            }
        }
    }

    public var color: NSColor {
        if !isRunning() {
            return .systemGray
        } else {
            if timeInactive() < 1.0 {
                return .systemGreen
            } else {
                return .systemOrange
            }
        }
    }
}

