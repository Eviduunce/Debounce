import XCTest
@testable import Debounce

private enum LaunchAtLoginTestError: Error, Equatable {
    case registrationFailed
}

private final class StubLaunchAtLoginService: LaunchAtLoginServicing {
    var isEnabled = false

    func register() throws {
        throw LaunchAtLoginTestError.registrationFailed
    }

    func unregister() throws {}
}

final class ConfigManagerTests: XCTestCase {
    func testLoadsStoredZeroGlobalThreshold() {
        let suiteName = "ConfigManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(0, forKey: "globalThreshold")

        let blocker = ChatterBlocker()
        blocker.globalThreshold = 100
        let manager = ConfigManager(defaults: defaults, migrateLegacySettings: false)

        manager.loadSettings(into: blocker)

        XCTAssertEqual(blocker.globalThreshold, 0)
    }

    func testPropagatesLaunchAtLoginRegistrationError() {
        let suiteName = "ConfigManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = ConfigManager(
            defaults: defaults,
            migrateLegacySettings: false,
            launchAtLoginService: StubLaunchAtLoginService()
        )

        XCTAssertThrowsError(try manager.setStartAtLogin(true)) { error in
            XCTAssertEqual(error as? LaunchAtLoginTestError, .registrationFailed)
        }
    }
}
