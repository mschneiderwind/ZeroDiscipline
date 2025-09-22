import AppKit
import Foundation

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
            let name = app.localizedName
        {
            return name
        }
        return URL(fileURLWithPath: appPath).lastPathComponent.replacingOccurrences(
            of: ".app", with: "")
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
            let launchDate = runningApp.launchDate
        else {
            print("🔍 \(displayName()): No running app found or no launchDate, using currentDate")
            return currentDate
        }

        let age = currentDate.timeIntervalSince(launchDate)
        print(
            "🔍 \(displayName()): Found PID=\(runningApp.processIdentifier), launchDate=\(launchDate), age=\(Int(age))s"
        )

        let result = max(currentDate, launchDate)
        print(
            "🔍 \(displayName()): Using \(result == currentDate ? "currentDate" : "launchDate") as lastUsed"
        )
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
            return bundlePath.hasPrefix(appPath) || bundlePath.contains(appName)
        }
    }

    /// Terminate this app and all related processes (non-blocking)
    public func terminate() {
        let processes = findRelatedProcesses()
        guard !processes.isEmpty else {
            print("⚠️ \(displayName()) not running")
            return
        }

        print("🎯 Terminating \(displayName()) (\(processes.count) processes)")

        // Terminate all processes immediately
        for process in processes {
            process.terminate()
        }

        // Schedule force-kill after 1 second (non-blocking)
        let appPath = self.appPath
        let displayName = self.displayName()
        Task.detached {
            try? await Task.sleep(for: .seconds(1))

            // Re-find processes after delay (they might have changed)
            let workspace = NSWorkspace.shared
            let appName = URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent
            let survivors = workspace.runningApplications.filter { app in
                guard let bundleURL = app.bundleURL else { return false }
                let bundlePath = bundleURL.path
                return bundlePath.hasPrefix(appPath) || bundlePath.contains(appName)
            }

            if !survivors.isEmpty {
                print("💥 Force-killing \(survivors.count) stubborn processes for \(displayName)")
                for survivor in survivors {
                    survivor.forceTerminate()
                }
            }
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
    private var lastFrontmostApp: String?

    public init(config: ZeroDisciplineConfig) {
        self.config = config

        print("🎯 Zero Discipline started - monitoring \(config.appPaths.count) apps")
        print(
            "⏰ Settings: \(config.inactivityDelay)s inactivity delay, keep top \(config.topN) apps in-use"
        )

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

        // Listen for app activation changes
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication,
                let bundlePath = app.bundleURL?.path
            {
                Task { @MainActor in
                    self?.lastFrontmostApp = bundlePath
                }
            }
        }
    }

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
                print(
                    "📆 App status before kill: \(app.displayName()) - lastUsed: \(app.lastUsed), timeInactive: \(app.timeInactive())s, shouldBeKilled: \(app.shouldBeKilled())"
                )
                app.terminate()
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
        // Get frontmost app first
        let workspace = NSWorkspace.shared
        var topApps: [String] = []

        // Add frontmost app first
        if let frontmostApp = workspace.frontmostApplication,
            frontmostApp.activationPolicy == .regular,
            !frontmostApp.isHidden,
            let frontmostPath = frontmostApp.bundleURL?.path
        {
            topApps.append(frontmostPath)
        }

        // Add other visible apps sorted by recent activity
        let otherApps = workspace.runningApplications
            .filter { app in
                guard app.activationPolicy == .regular,
                    !app.isHidden,
                    let bundlePath = app.bundleURL?.path
                else { return false }
                // Don't include frontmost app again
                return !topApps.contains(bundlePath)
            }
            .sorted { app1, app2 in
                // Sort by PID as rough proxy for recency
                return app1.processIdentifier > app2.processIdentifier
            }
            .prefix(config.topN - topApps.count)
            .compactMap { $0.bundleURL?.path }

        topApps.append(contentsOf: otherApps)
        return Array(topApps.prefix(config.topN))
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
