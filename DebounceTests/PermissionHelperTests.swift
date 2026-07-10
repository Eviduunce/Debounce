import XCTest
@testable import Debounce

@MainActor
final class PermissionHelperTests: XCTestCase {
    func testResetIsScopedToCurrentBundleIdentifier() throws {
        var capturedArguments: [String] = []
        let helper = PermissionHelper(
            bundleIdentifier: "com.example.Debounce",
            resetRunner: { arguments in
                capturedArguments = arguments
                return 0
            }
        )

        try helper.resetAccessibilityPermission()

        XCTAssertEqual(capturedArguments, ["reset", "Accessibility", "com.example.Debounce"])
    }

    func testResetThrowsLocalizedErrorForNonzeroExitStatus() {
        let helper = PermissionHelper(
            bundleIdentifier: "com.example.Debounce",
            resetRunner: { _ in 17 }
        )

        XCTAssertThrowsError(try helper.resetAccessibilityPermission()) { error in
            XCTAssertEqual(error as? PermissionHelperError, .resetFailed(exitStatus: 17))
            XCTAssertTrue(error.localizedDescription.contains("17"))
        }
    }

    func testResetRejectsMissingBundleIdentifierWithoutRunningCommand() {
        var didRunReset = false
        let helper = PermissionHelper(
            bundleIdentifier: nil,
            resetRunner: { _ in
                didRunReset = true
                return 0
            }
        )

        XCTAssertThrowsError(try helper.resetAccessibilityPermission()) { error in
            XCTAssertEqual(error as? PermissionHelperError, .bundleIdentifierUnavailable)
        }
        XCTAssertFalse(didRunReset)
    }

    func testTrustCheckForwardsNativePromptFlag() {
        var capturedPrompt: Bool?
        let helper = PermissionHelper(
            bundleIdentifier: "com.example.Debounce",
            resetRunner: { _ in 0 },
            trustChecker: { prompt in
                capturedPrompt = prompt
                return false
            }
        )

        XCTAssertFalse(helper.isAccessibilityTrusted(prompt: true))

        XCTAssertEqual(capturedPrompt, true)
    }

    func testOpenSettingsActionPromptsBeforeOpeningAccessibilitySettings() throws {
        var actions: [String] = []
        let helper = PermissionHelper(
            bundleIdentifier: "com.example.Debounce",
            resetRunner: { _ in 0 },
            trustChecker: { prompt in
                actions.append("prompt:\(prompt)")
                return false
            },
            alertPresenter: { .openSettings },
            preferencesOpener: { actions.append("openSettings") }
        )

        XCTAssertEqual(try helper.showPermissionAlert(), .openSettings)
        XCTAssertEqual(actions, ["prompt:true", "openSettings"])
    }

    func testRepairActionResetsThenPromptsBeforeOpeningAccessibilitySettings() throws {
        var actions: [String] = []
        let helper = PermissionHelper(
            bundleIdentifier: "com.example.Debounce",
            resetRunner: { arguments in
                actions.append(arguments.joined(separator: " "))
                return 0
            },
            trustChecker: { prompt in
                actions.append("prompt:\(prompt)")
                return false
            },
            alertPresenter: { .repairPermission },
            preferencesOpener: { actions.append("openSettings") }
        )

        XCTAssertEqual(try helper.showPermissionAlert(), .repairPermission)
        XCTAssertEqual(actions, [
            "reset Accessibility com.example.Debounce",
            "prompt:true",
            "openSettings"
        ])
    }

    func testCancelActionDoesNotTouchPermissionState() throws {
        var actions: [String] = []
        let helper = PermissionHelper(
            bundleIdentifier: "com.example.Debounce",
            resetRunner: { _ in
                actions.append("reset")
                return 0
            },
            trustChecker: { prompt in
                actions.append("prompt:\(prompt)")
                return false
            },
            alertPresenter: { .cancel },
            preferencesOpener: { actions.append("openSettings") }
        )

        XCTAssertEqual(try helper.showPermissionAlert(), .cancel)
        XCTAssertTrue(actions.isEmpty)
    }

    func testAlertExplainsWhenRepairShouldBeUsed() {
        XCTAssertTrue(
            PermissionHelper.permissionAlertInformativeText.localizedCaseInsensitiveContains(
                "already appears enabled"
            )
        )
    }
}
