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
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        var seenPIDs = Set<pid_t>()
        var orderedAppPaths: [String] = []

        for window in windowList {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  !seenPIDs.contains(pid),
                  let app = NSRunningApplication(processIdentifier: pid),
                  let bundlePath = app.bundleURL?.path,
                  isValidUserApp(app: app, window: window) else { continue }

            orderedAppPaths.append(bundlePath)
            seenPIDs.insert(pid)

            if orderedAppPaths.count >= self.config.topN { break }
        }

        return orderedAppPaths
    }

    private func isValidUserApp(app: NSRunningApplication, window: [String: Any]) -> Bool {
        guard app.activationPolicy == .regular else { return false }
        guard !app.isHidden else { return false }

        let windowLayer = window[kCGWindowLayer as String] as? Int ?? 0
        guard windowLayer == 0 else { return false }

        guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
              let width = bounds["Width"] as? Double,
              let height = bounds["Height"] as? Double,
              width > 50 && height > 50 else { return false }

        return true
    }



    @discardableResult
    private func quitApp(app: MonitoredAppStatus) -> Bool {
        guard let runningApp = app.findRunningApp() else {
            print("⚠️ App \(app.displayName()) not found or not running")
            return false
        }

        let appName = app.displayName()

        print("🎯 Terminating \(appName)")

        let success = runningApp.terminate()

        if success {
            print("✅ terminate() returned true for \(appName), waiting for app to close...")

            // Wait for the app to actually close (max 3 seconds before force kill)
            let gracePeriod: TimeInterval = 3.0
            let startTime = Date()

            while Date().timeIntervalSince(startTime) < gracePeriod {
                if app.findRunningApp() == nil {
                    print("✅ \(appName) successfully closed after \(Date().timeIntervalSince(startTime))s")
                    return true
                }
                Thread.sleep(forTimeInterval: 0.1)
            }

            // App didn't close gracefully, try force terminate
            if let stubornApp = app.findRunningApp() {
                print("💥 \(appName) didn't close gracefully, force terminating...")
                let forceSuccess = stubornApp.forceTerminate()
                print("forceTerminate() returned: \(forceSuccess)")
                
                // Wait a bit more for force terminate
                let forceStartTime = Date()
                while Date().timeIntervalSince(forceStartTime) < 2.0 {
                    if app.findRunningApp() == nil {
                        print("✅ \(appName) force terminated after \(Date().timeIntervalSince(startTime))s total")
                        return true
                    }
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }

            print("⚠️ \(appName) couldn't be terminated, giving up")
            return false
        } else {
            print("⚠️ terminate() returned false for \(appName)")
            return false
        }
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

