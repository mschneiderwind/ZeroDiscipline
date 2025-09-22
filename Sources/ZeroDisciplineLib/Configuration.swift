import Foundation

/// Configuration model for Zero Discipline
public struct ZeroDisciplineConfig: Codable {
    var appPaths: [String]  // Changed from apps to appPaths
    var inactivityDelay: Int  // Seconds before closing inactive app
    var topN: Int  // Number of most recently used apps to keep protected
    
    private enum CodingKeys: String, CodingKey {
        case appPaths = "app_paths"  // Use snake_case for JSON
        case inactivityDelay = "inactivity_delay"
        case topN = "top_n"
    }
    
    public static let `default` = ZeroDisciplineConfig(
        appPaths: [],  // Empty by default - user will add via file picker
        inactivityDelay: 10,
        topN: 3
    )
}

/// Configuration manager that reads/writes to config.json
public class ConfigurationManager: ObservableObject {
    @Published public var config: ZeroDisciplineConfig
    private let configURL: URL
    
    public init(configPath: String? = nil) {
        // Use the same config.json as the Python version by default
        if let configPath = configPath {
            self.configURL = URL(fileURLWithPath: configPath)
        } else {
            let currentDir = FileManager.default.currentDirectoryPath
            self.configURL = URL(fileURLWithPath: currentDir).appendingPathComponent("config.json")
        }
        
        self.config = Self.loadConfig(from: configURL)
    }
    
    private static func loadConfig(from url: URL) -> ZeroDisciplineConfig {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(ZeroDisciplineConfig.self, from: data)
        } catch {
            print("Failed to load config from \(url.path): \(error)")
            print("Using default configuration")
            return .default
        }
    }
    
    func saveConfig() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configURL)
            print("Configuration saved to \(configURL.path)")
        } catch {
            print("Failed to save config: \(error)")
        }
    }
    
    func addApp(path: String) {
        guard !config.appPaths.contains(path) && !path.isEmpty else { return }
        config.appPaths.append(path)
        saveConfig()
    }
    
    func removeApp(path: String) {
        config.appPaths.removeAll { $0 == path }
        saveConfig()
    }
    
    func updateInactivityDelay(delay: Int) {
        guard delay > 0 else { return }
        config.inactivityDelay = delay
        saveConfig()
    }
    
    func updateTopN(topN: Int) {
        guard topN > 0 else { return }
        config.topN = topN
        saveConfig()
    }
}