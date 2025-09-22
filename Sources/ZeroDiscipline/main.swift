import AppKit
import SwiftUI
import ZeroDisciplineLib

@main
struct ZeroDisciplineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var _appDelegate

    var body: some Scene {
        // We use MenuBarExtra for the system tray, but since we want full control,
        // we'll handle it through AppDelegate instead
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var configManager: ConfigurationManager!
    private var appMonitor: AppMonitor!
    private var systemTrayManager: SystemTrayManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Don't show the app in the dock
        NSApp.setActivationPolicy(.accessory)

        // Initialize components
        configManager = ConfigurationManager()
        appMonitor = AppMonitor(config: configManager.config)
        systemTrayManager = SystemTrayManager(configManager: configManager, appMonitor: appMonitor)

        print("⚙️ Configuration: \(FileManager.default.currentDirectoryPath)/config.json")
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("Zero Discipline terminated")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        // Don't quit when configuration window is closed
        return false
    }
}
