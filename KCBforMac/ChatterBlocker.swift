//
//  ChatterBlocker.swift
//  KCBforMac
//
//  Created by Timo Leisengang on 07.10.25.
//

import Foundation
import CoreGraphics
import Combine

/// Core chatter detection and blocking logic
class ChatterBlocker: ObservableObject {

    // MARK: - Published Properties
    @Published var isEnabled: Bool = false
    @Published var globalThreshold: UInt64 = 100 // milliseconds
    @Published var chatterLog: [ChatterEvent] = []
    @Published var statistics: [CGKeyCode: (presses: Int, chatters: Int)] = [:]

    // MARK: - Private Properties
    private var keyToLastPressTime: [CGKeyCode: UInt64] = [:]
    private var keyToLastReleaseTime: [CGKeyCode: UInt64] = [:]
    private var keyToThreshold: [CGKeyCode: UInt64] = [:]
    private var keyIsDown: [CGKeyCode: Bool] = [:]
    private var keyDownWasBlocked: [CGKeyCode: Bool] = [:]

    // MARK: - Configuration
    var minimumChatterTime: UInt64 = 0 // ms - ignores chatter faster than this (helps with buggy inputs)
    var measureFromRelease: Bool = false // if true, measure from last release instead of last press
    private let maxLogEntries = 100

    // MARK: - Timing
    private func getCurrentTime() -> UInt64 {
        // Convert system uptime to milliseconds
        return UInt64(ProcessInfo.processInfo.systemUptime * 1000)
    }

    // MARK: - Key Event Handling

    /// Called when a key down event is detected
    /// Returns true to allow the event, false to block it
    func shouldAllowKeyDown(keyCode: CGKeyCode) -> Bool {
        guard isEnabled else {
            return true
        }

        // Check if key is already down (key being held, not chatter)
        if keyIsDown[keyCode] == true {
            return true
        }

        // Mark key as down
        keyIsDown[keyCode] = true

        let timeNow = getCurrentTime()
        let threshold = keyToThreshold[keyCode] ?? globalThreshold

        // Fast path: if threshold is 0, always allow
        if threshold == 0 {
            keyToLastPressTime[keyCode] = timeNow
            updateStatistics(for: keyCode, isChatter: false)
            return true
        }

        // Get last relevant time (either press or release based on config)
        let lastTime = measureFromRelease ?
            (keyToLastReleaseTime[keyCode] ?? 0) :
            (keyToLastPressTime[keyCode] ?? 0)

        // Check if this is a new first-time press
        if lastTime == 0 {
            keyToLastPressTime[keyCode] = timeNow
            updateStatistics(for: keyCode, isChatter: false)
            return true
        }

        // Calculate time elapsed since last event
        if timeNow < lastTime {
            // Time went backwards (system clock change), allow it
            keyToLastPressTime[keyCode] = timeNow
            updateStatistics(for: keyCode, isChatter: false)
            return true
        }

        let timeDelta = timeNow - lastTime

        // Check if enough time has passed OR if it's too fast (below minimum, likely a bug)
        if timeDelta >= threshold || timeDelta < minimumChatterTime {
            keyToLastPressTime[keyCode] = timeNow
            updateStatistics(for: keyCode, isChatter: false)
            return true
        }

        // CHATTER DETECTED - Block the key
        keyDownWasBlocked[keyCode] = true

        // Update statistics for blocked chatter
        updateStatistics(for: keyCode, isChatter: true)

        // Log the chatter event
        logChatterEvent(keyCode: keyCode, timeDelta: timeDelta)

        return false
    }

    /// Called when a key up event is detected
    /// Returns true to allow the event, false to block it
    func shouldAllowKeyUp(keyCode: CGKeyCode) -> Bool {
        let timeNow = getCurrentTime()
        keyToLastReleaseTime[keyCode] = timeNow
        keyIsDown[keyCode] = false

        guard isEnabled else { return true }

        // If the down event was blocked, block the up event too
        if keyDownWasBlocked[keyCode] == true {
            keyDownWasBlocked[keyCode] = false
            return false
        }

        return true
    }

    // MARK: - Configuration

    /// Set a custom threshold for a specific key
    func setThreshold(_ threshold: UInt64, for keyCode: CGKeyCode) {
        keyToThreshold[keyCode] = threshold
    }

    /// Remove custom threshold for a key (will use global threshold)
    func removeThreshold(for keyCode: CGKeyCode) {
        keyToThreshold.removeValue(forKey: keyCode)
    }

    /// Get threshold for a specific key
    func getThreshold(for keyCode: CGKeyCode) -> UInt64 {
        return keyToThreshold[keyCode] ?? globalThreshold
    }

    /// Get all configured custom key thresholds
    func getCustomThresholds() -> [CGKeyCode: UInt64] {
        return keyToThreshold
    }

    // MARK: - Statistics & Logging

    private func updateStatistics(for keyCode: CGKeyCode, isChatter: Bool) {
        // Perform the entire update on main thread to avoid race conditions
        DispatchQueue.main.async {
            var stats = self.statistics[keyCode] ?? (presses: 0, chatters: 0)

            if isChatter {
                stats.chatters += 1
            } else {
                stats.presses += 1
            }

            self.statistics[keyCode] = stats
        }
    }

    private func logChatterEvent(keyCode: CGKeyCode, timeDelta: UInt64) {
        let event = ChatterEvent(
            timestamp: Date(),
            keyCode: keyCode,
            keyName: KeyCodeMapper.keyName(for: keyCode),
            timeDelta: timeDelta
        )

        DispatchQueue.main.async {
            self.chatterLog.insert(event, at: 0)

            // Limit log size
            if self.chatterLog.count > self.maxLogEntries {
                self.chatterLog.removeLast()
            }
        }
    }

    /// Clear the chatter log
    func clearLog() {
        DispatchQueue.main.async {
            self.chatterLog.removeAll()
        }
    }

    /// Reset all statistics
    func resetStatistics() {
        DispatchQueue.main.async {
            self.statistics.removeAll()
        }
    }

    /// Reset all timing data (useful when enabling/disabling)
    func resetTimingData() {
        keyToLastPressTime.removeAll()
        keyToLastReleaseTime.removeAll()
        keyIsDown.removeAll()
        keyDownWasBlocked.removeAll()
    }
}
