//
//  PermissionHelper.swift
//  Debounce
//
//  Created by Timo Leisengang on 07.10.25.
//

import Cocoa
import ApplicationServices

protocol AccessibilityPermissionChecking {
    func isAccessibilityTrusted(prompt: Bool) -> Bool
}

enum PermissionAlertAction: Equatable {
    case openSettings
    case repairPermission
    case cancel
}

enum PermissionHelperError: LocalizedError, Equatable {
    case bundleIdentifierUnavailable
    case resetFailed(exitStatus: Int32)

    var errorDescription: String? {
        switch self {
        case .bundleIdentifierUnavailable:
            return NSLocalizedString(
                "Debounce could not determine its bundle identifier, so the Accessibility permission was not changed.",
                comment: "Missing bundle identifier during Accessibility permission repair"
            )
        case .resetFailed(let exitStatus):
            let format = NSLocalizedString(
                "Debounce could not repair its Accessibility permission because tccutil exited with status %d.",
                comment: "Accessibility permission repair command failure"
            )
            return String(format: format, exitStatus)
        }
    }
}

/// Helper class for managing accessibility permissions required for event monitoring
final class PermissionHelper: AccessibilityPermissionChecking {
    typealias ResetRunner = ([String]) throws -> Int32
    typealias TrustChecker = (Bool) -> Bool
    typealias AlertPresenter = () -> PermissionAlertAction
    typealias PreferencesOpener = () -> Void

    static let permissionAlertInformativeText = NSLocalizedString(
        """
        Debounce needs Accessibility permission to monitor keyboard events and block chatter.

        Choose “Open System Settings” to grant access. If Debounce already appears enabled there but still reports missing permission, choose “Repair Permission” to remove only Debounce’s stale entry and ask macOS again.
        """,
        comment: "Accessibility permission and stale-entry repair explanation"
    )

    private let bundleIdentifier: String?
    private let resetRunner: ResetRunner
    private let trustChecker: TrustChecker
    private let alertPresenter: AlertPresenter
    private let preferencesOpener: PreferencesOpener

    init(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        resetRunner: ResetRunner? = nil,
        trustChecker: TrustChecker? = nil,
        alertPresenter: AlertPresenter? = nil,
        preferencesOpener: PreferencesOpener? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.resetRunner = resetRunner ?? { arguments in
            try PermissionHelper.runTCCUtil(arguments: arguments)
        }
        self.trustChecker = trustChecker ?? { prompt in
            PermissionHelper.checkAccessibilityTrust(prompt: prompt)
        }
        self.alertPresenter = alertPresenter ?? {
            PermissionHelper.presentPermissionAlert()
        }
        self.preferencesOpener = preferencesOpener ?? {
            PermissionHelper.openSystemAccessibilityPreferences()
        }
    }

    func isAccessibilityTrusted(prompt: Bool) -> Bool {
        trustChecker(prompt)
    }

    func resetAccessibilityPermission() throws {
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else {
            throw PermissionHelperError.bundleIdentifierUnavailable
        }

        let arguments = ["reset", "Accessibility", bundleIdentifier]
        let exitStatus = try resetRunner(arguments)
        guard exitStatus == 0 else {
            throw PermissionHelperError.resetFailed(exitStatus: exitStatus)
        }
    }

    /// Shows the recovery alert and performs only the action explicitly selected by the user.
    @discardableResult
    func showPermissionAlert() throws -> PermissionAlertAction {
        let action = alertPresenter()

        switch action {
        case .openSettings:
            requestNativePromptAndOpenSettings()
        case .repairPermission:
            try resetAccessibilityPermission()
            requestNativePromptAndOpenSettings()
        case .cancel:
            break
        }

        return action
    }

    /// Open System Settings to the Accessibility panel.
    func openAccessibilityPreferences() {
        preferencesOpener()
    }

    private func requestNativePromptAndOpenSettings() {
        _ = isAccessibilityTrusted(prompt: true)
        openAccessibilityPreferences()
    }

    private static func checkAccessibilityTrust(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Check if the app has accessibility permissions
    static func hasAccessibilityPermissions() -> Bool {
        PermissionHelper().isAccessibilityTrusted(prompt: false)
    }

    /// Check permissions, showing an explanatory alert with a link to System Settings if missing.
    /// Returns the current trust state.
    static func ensureAccessibilityPermissions() -> Bool {
        if hasAccessibilityPermissions() {
            return true
        }
        _ = try? PermissionHelper().showPermissionAlert()
        return false
    }

    private static func runTCCUtil(arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    private static func presentPermissionAlert() -> PermissionAlertAction {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = permissionAlertInformativeText
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Repair Permission")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .openSettings
        case .alertSecondButtonReturn:
            return .repairPermission
        default:
            return .cancel
        }
    }

    private static func openSystemAccessibilityPreferences() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
