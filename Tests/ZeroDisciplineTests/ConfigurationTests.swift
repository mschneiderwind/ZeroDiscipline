import XCTest
@testable import ZeroDisciplineLib

final class ConfigurationTests: XCTestCase {
    func testDefaultConfiguration() {
        let defaultConfig = ZeroDisciplineConfig.default
        
        XCTAssertEqual(defaultConfig.apps.count, 3)
        XCTAssertEqual(defaultConfig.timeout, 10)
        XCTAssertEqual(defaultConfig.topN, 3)
        XCTAssertTrue(defaultConfig.apps.contains("WhatsApp"))
        XCTAssertTrue(defaultConfig.apps.contains("Firefox"))
        XCTAssertTrue(defaultConfig.apps.contains("Slack"))
    }
}