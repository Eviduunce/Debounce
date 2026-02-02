//
//  ConfigManager.swift
//  KCBforMac
//
//  Created by Timo Leisengang on 07.10.25.
//

import Foundation
import CoreGraphics

/// Manages persistence of application configuration
class ConfigManager {

    private let defaults = UserDefaults.standard

    // Keys for UserDefaults
    private enum Keys {
        static let isEnabled = "isEnabled"
        static let globalThreshold = "globalThreshold"
        static let minimumChatterTime = "minimumChatterTime"
        static let measureFromRelease = "measureFromRelease"
        static let customThresholds = "customThresholds"
        static let startAtLogin = "startAtLogin"
    }

    // MARK: - Save Configuration

    /// Save all settings from the ChatterBlocker
    func saveSettings(from blocker: ChatterBlocker) {
        defaults.set(blocker.isEnabled, forKey: Keys.isEnabled)
        defaults.set(Int(blocker.globalThreshold), forKey: Keys.globalThreshold)
        defaults.set(Int(blocker.minimumChatterTime), forKey: Keys.minimumChatterTime)
        defaults.set(blocker.measureFromRelease, forKey: Keys.measureFromRelease)

        // Save custom key thresholds as [String: Int]
        let customThresholds = blocker.getCustomThresholds()
        var thresholdsDict: [String: Int] = [:]
        for (key, value) in customThresholds {
            thresholdsDict[String(key)] = Int(value)
        }
        defaults.set(thresholdsDict, forKey: Keys.customThresholds)
    }

    // MARK: - Load Configuration

    /// Load all settings into the ChatterBlocker
    func loadSettings(into blocker: ChatterBlocker) {
        blocker.isEnabled = defaults.bool(forKey: Keys.isEnabled)

        let globalThreshold = defaults.integer(forKey: Keys.globalThreshold)
        if globalThreshold > 0 {
            blocker.globalThreshold = UInt64(globalThreshold)
        }

        let minimumChatterTime = defaults.integer(forKey: Keys.minimumChatterTime)
        blocker.minimumChatterTime = UInt64(minimumChatterTime)

        blocker.measureFromRelease = defaults.bool(forKey: Keys.measureFromRelease)

        // Load custom key thresholds
        if let thresholdsDict = defaults.dictionary(forKey: Keys.customThresholds) as? [String: Int] {
            for (keyString, threshold) in thresholdsDict {
                if let keyCode = CGKeyCode(keyString) {
                    blocker.setThreshold(UInt64(threshold), for: keyCode)
                }
            }
        }
    }

    // MARK: - Individual Settings

    /// Get start at login preference
    func getStartAtLogin() -> Bool {
        return defaults.bool(forKey: Keys.startAtLogin)
    }

    /// Set start at login preference
    func setStartAtLogin(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.startAtLogin)
    }
}
