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
        defaults.set(blocker.globalThreshold, forKey: Keys.globalThreshold)
        defaults.set(blocker.minimumChatterTime, forKey: Keys.minimumChatterTime)
        defaults.set(blocker.measureFromRelease, forKey: Keys.measureFromRelease)

        // Save custom key thresholds as dictionary [String: UInt64]
        let customThresholds = blocker.getCustomThresholds()
        let thresholdsDict = customThresholds.mapKeys { String($0) }
        defaults.set(thresholdsDict, forKey: Keys.customThresholds)

        defaults.synchronize()
    }

    // MARK: - Load Configuration

    /// Load all settings into the ChatterBlocker
    func loadSettings(into blocker: ChatterBlocker) {
        blocker.isEnabled = defaults.bool(forKey: Keys.isEnabled)

        if let globalThreshold = defaults.object(forKey: Keys.globalThreshold) as? UInt64 {
            blocker.globalThreshold = globalThreshold
        }

        if let minimumChatterTime = defaults.object(forKey: Keys.minimumChatterTime) as? UInt64 {
            blocker.minimumChatterTime = minimumChatterTime
        }

        blocker.measureFromRelease = defaults.bool(forKey: Keys.measureFromRelease)

        // Load custom key thresholds
        if let thresholdsDict = defaults.dictionary(forKey: Keys.customThresholds) as? [String: UInt64] {
            for (keyString, threshold) in thresholdsDict {
                if let keyCode = CGKeyCode(keyString) {
                    blocker.setThreshold(threshold, for: keyCode)
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
        defaults.synchronize()
    }
}

// MARK: - Helper Extensions

private extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }
}
