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

/// Helper class for managing accessibility permissions required for event monitoring
final class PermissionHelper: AccessibilityPermissionChecking {

    func isAccessibilityTrusted(prompt: Bool) -> Bool {
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
        showPermissionAlert()
        return false
    }

    /// Open System Settings to Accessibility panel
    static func openAccessibilityPreferences() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    /// Show alert explaining permission requirement
    static func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        Debounce needs accessibility permissions to monitor keyboard events and block chatter.

        Click "Open System Settings" to grant permission, then enable Debounce again.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilityPreferences()
        }
    }
}
