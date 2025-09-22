import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct ConfigurationView: View {
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var appMonitor: AppMonitor
    
    public init(configManager: ConfigurationManager, appMonitor: AppMonitor) {
        self.configManager = configManager
        self.appMonitor = appMonitor
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // General Settings
            GroupBox("General Settings") {
                VStack(spacing: 12) {
                    Stepper(value: $configManager.config.inactivityDelay, in: 1...999, step: 1) {
                        Text("Inactivity delay: \(configManager.config.inactivityDelay) seconds")
                    } onEditingChanged: { _ in
                        configManager.updateInactivityDelay(delay: configManager.config.inactivityDelay)
                    }
                    
                    Stepper(value: $configManager.config.topN, in: 1...5, step: 1) {
                        Text("In-use apps count: \(configManager.config.topN) apps")
                    } onEditingChanged: { _ in
                        configManager.updateTopN(topN: configManager.config.topN)
                    }
                }
                .padding()
            }
            
            // Monitored Apps
            GroupBox("Monitored Apps") {
                VStack(spacing: 12) {
                    // Add new app section
                    HStack {
                        Text("Add application to monitor:")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Browse Applications...") {
                            selectAppFromFileSystem()
                        }
                        .buttonStyle(.borderedProminent)
                        .help("Select an application from the filesystem")
                    }
                    
                    Divider()
                    
                    // Apps list
                    if configManager.config.appPaths.isEmpty {
                        Text("No applications monitored")
                            .foregroundColor(.secondary)
                            .italic()
                            .padding()
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(appMonitor.monitoredApps, id: \.appPath) { app in
                                AppRowView(
                                    appPath: app.appPath,
                                    status: app,
                                    inactivityDelay: configManager.config.inactivityDelay,
                                    onRemove: {
                                        configManager.removeApp(path: app.appPath)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            
        }
        .padding()
        .frame(minWidth: 420, minHeight: 420)
    }
    
    private func selectAppFromFileSystem() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Application to Monitor"
        openPanel.message = "Choose an application to add to the monitoring list"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = false
        
        // Filter to show only applications
        openPanel.allowedContentTypes = [.application]
        
        // Start in Applications folder
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        openPanel.begin { response in
            guard response == .OK,
                  let selectedURL = openPanel.url else { return }
            
            DispatchQueue.main.async {
                // Add the selected app directly
                self.configManager.addApp(path: selectedURL.path)
                print("✅ Added app: \(selectedURL.path)")
            }
        }
    }
    
}

struct AppRowView: View {
    let appPath: String
    let status: MonitoredAppStatus
    let inactivityDelay: Int
    let onRemove: () -> Void
    
    private var appName: String {
        status.displayName()
    }
    
    private var appIcon: NSImage {
        NSWorkspace.shared.icon(forFile: appPath)
    }
    
    var body: some View {
        HStack {
            // Real app icon
            Image(nsImage: appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                // App name only (clean)
                Text(appName)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            // Status
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(status.color))
                    .frame(width: 8, height: 8)
                
                Text(status.displayText(inactivityDelay: inactivityDelay))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Remove button
            Button {
                onRemove()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("Remove \(appName) from monitoring")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}

