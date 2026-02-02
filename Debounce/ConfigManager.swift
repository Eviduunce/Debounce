//
//  ConfigManager.swift
//  Debounce
//
//  Created by Timo Leisengang on 07.10.25.
//

import Foundation
import CoreGraphics
import ServiceManagement

/// Manages persistence of application configuration
class ConfigManager {

    private let defaults = UserDefaults.standard

    init() {
        migrateFromOldBundleIfNeeded()
    }

    /// Migrate settings from old bundle ID (com.leisengang.KCBforMac) on first launch
    private func migrateFromOldBundleIfNeeded() {
        let migrationKey = "didMigrateFromKCBforMac"
        guard !defaults.bool(forKey: migrationKey) else { return }

        guard let oldDefaults = UserDefaults(suiteName: "com.leisengang.KCBforMac") else {
            defaults.set(true, forKey: migrationKey)
            return
        }

        let oldDict = oldDefaults.dictionaryRepresentation()
        guard !oldDict.isEmpty else {
            defaults.set(true, forKey: migrationKey)
            return
        }

        // Copy all keys from old domain
        for (key, value) in oldDict {
            defaults.set(value, forKey: key)
        }

        // Clean up old domain
        for key in oldDict.keys {
            oldDefaults.removeObject(forKey: key)
        }

        defaults.set(true, forKey: migrationKey)
    }

    // Keys for UserDefaults
    private enum Keys {
        static let isEnabled = "isEnabled"
        static let globalThreshold = "globalThreshold"
        static let minimumChatterTime = "minimumChatterTime"
        static let measureFromRelease = "measureFromRelease"
        static let customThresholds = "customThresholds"
        static let startAtLogin = "startAtLogin"
        static let statistics = "statistics"
        static let hasLaunchedBefore = "hasLaunchedBefore"
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

    // MARK: - Launch at Login

    func getStartAtLogin() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }

    func setStartAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Registration can fail if app is not in /Applications
        }
    }

    // MARK: - Statistics Persistence

    func saveStatistics(from blocker: ChatterBlocker) {
        var dict: [String: [String: Int]] = [:]
        for (keyCode, stats) in blocker.statistics {
            dict[String(keyCode)] = ["presses": stats.presses, "chatters": stats.chatters]
        }
        defaults.set(dict, forKey: Keys.statistics)
    }

    func loadStatistics(into blocker: ChatterBlocker) {
        guard let dict = defaults.dictionary(forKey: Keys.statistics) as? [String: [String: Int]] else { return }
        var stats: [CGKeyCode: (presses: Int, chatters: Int)] = [:]
        for (keyString, values) in dict {
            if let keyCode = CGKeyCode(keyString) {
                let presses = values["presses"] ?? 0
                let chatters = values["chatters"] ?? 0
                stats[keyCode] = (presses: presses, chatters: chatters)
            }
        }
        blocker.statistics = stats
    }

    // MARK: - First Launch

    var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: Keys.hasLaunchedBefore) }
        set { defaults.set(newValue, forKey: Keys.hasLaunchedBefore) }
    }
}
