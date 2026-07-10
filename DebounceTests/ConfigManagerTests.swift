import ServiceManagement
import XCTest
@testable import Debounce

private enum LaunchAtLoginTestError: Error, Equatable {
    case registrationFailed
}

private final class StubLaunchAtLoginService: LaunchAtLoginServicing {
    var status: SMAppService.Status
    private let registrationError: Error?
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0
    private(set) var openSettingsCount = 0

    init(
        status: SMAppService.Status = .notRegistered,
        registrationError: Error? = LaunchAtLoginTestError.registrationFailed
    ) {
        self.status = status
        self.registrationError = registrationError
    }

    func register() throws {
        registerCount += 1
        if let registrationError {
            throw registrationError
        }
    }

    func unregister() throws {
        unregisterCount += 1
    }

    func openSystemSettingsLoginItems() {
        openSettingsCount += 1
    }
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

    func testDoesNotUnregisterWhenLaunchAtLoginIsAlreadyDisabled() throws {
        let service = StubLaunchAtLoginService()
        let manager = ConfigManager(
            migrateLegacySettings: false,
            launchAtLoginService: service
        )

        try manager.setStartAtLogin(false)

        XCTAssertEqual(service.unregisterCount, 0)
    }

    func testUnregistersLaunchAtLoginThatRequiresApproval() throws {
        let service = StubLaunchAtLoginService(status: .requiresApproval)
        let manager = ConfigManager(
            migrateLegacySettings: false,
            launchAtLoginService: service
        )

        try manager.setStartAtLogin(false)

        XCTAssertEqual(service.unregisterCount, 1)
    }

    func testEnablingLaunchAtLoginThatRequiresApprovalSurfacesGuidance() {
        let service = StubLaunchAtLoginService(status: .requiresApproval)
        let manager = ConfigManager(
            migrateLegacySettings: false,
            launchAtLoginService: service
        )

        XCTAssertThrowsError(try manager.setStartAtLogin(true)) { error in
            XCTAssertEqual(error as? LaunchAtLoginError, .approvalRequired)
            XCTAssertTrue(error.localizedDescription.contains("System Settings"))
            XCTAssertTrue(error.localizedDescription.contains("Login Items"))
        }

        XCTAssertEqual(service.registerCount, 0)
    }

    func testReportsLaunchAtLoginThatRequiresApprovalAsNotEnabled() {
        let manager = ConfigManager(
            migrateLegacySettings: false,
            launchAtLoginService: StubLaunchAtLoginService(status: .requiresApproval)
        )

        XCTAssertFalse(manager.getStartAtLogin())
    }

    func testOpensLoginItemsSettingsThroughService() {
        let service = StubLaunchAtLoginService()
        let manager = ConfigManager(
            migrateLegacySettings: false,
            launchAtLoginService: service
        )

        manager.openLoginItemsSettings()

        XCTAssertEqual(service.openSettingsCount, 1)
    }
}
