//
//  PermissionHelper.swift
//  KCBforMac
//
//  Created by Timo Leisengang on 07.10.25.
//

import Cocoa
import ApplicationServices

/// Helper class for managing accessibility permissions required for event monitoring
class PermissionHelper {

    /// Check if the app has accessibility permissions
    static func hasAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Request accessibility permissions with system prompt
    static func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Preferences to Accessibility panel
    static func openAccessibilityPreferences() {
        if #available(macOS 13.0, *) {
            // macOS 13+ uses new System Settings app
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        } else {
            // macOS 12 and earlier use System Preferences
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    /// Show alert explaining permission requirement
    static func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        KCBforMac needs accessibility permissions to monitor keyboard events and block chatter.

        Click "Open System Settings" to grant permission, then restart the app.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilityPreferences()
        }
    }
}
