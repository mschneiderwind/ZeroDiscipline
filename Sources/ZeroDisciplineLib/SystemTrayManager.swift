import Foundation
import AppKit
import SwiftUI

@MainActor
public class SystemTrayManager {
    private var statusItem: NSStatusItem?
    private let configManager: ConfigurationManager
    private let appMonitor: AppMonitor
    private var configWindow: NSWindow?
    
    public init(configManager: ConfigurationManager, appMonitor: AppMonitor) {
        self.configManager = configManager
        self.appMonitor = appMonitor
        setupSystemTray()
    }
    
    // Note: NSStatusItem cleanup handled by ARC
    
    private func setupSystemTray() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusItem = statusItem else { return }
        
        // Set the icon
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "target", accessibilityDescription: "Zero Discipline")
            button.image?.size = NSSize(width: 18, height: 18)
        }
        
        // Create menu
        let menu = NSMenu()
        statusItem.menu = menu
        
        setupMenuItems()
    }
    
    private func setupMenuItems() {
        guard let menu = statusItem?.menu else { return }
        
        // Title
        let titleItem = NSMenuItem(title: "Zero Discipline", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Configuration
        let configItem = NSMenuItem(title: "Configuration...", action: #selector(showConfiguration), keyEquivalent: ",")
        configItem.target = self
        menu.addItem(configItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit Zero Discipline", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    @objc private func showConfiguration() {
        if configWindow == nil {
            createConfigurationWindow()
        }
        
        configWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func createConfigurationWindow() {
        let contentView = ConfigurationView(configManager: configManager, appMonitor: appMonitor)
        
        configWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        configWindow?.title = "Zero Discipline Configuration"
        configWindow?.contentView = NSHostingView(rootView: contentView)
        configWindow?.center()
        configWindow?.setFrameAutosaveName("ZeroDisciplineConfig")
        
        // Close window when user clicks close button (don't quit app)
        configWindow?.isReleasedWhenClosed = false
    }
    
    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }
}

