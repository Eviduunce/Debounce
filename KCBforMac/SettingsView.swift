//
//  SettingsView.swift
//  KCBforMac
//
//  Created by Timo Leisengang on 07.10.25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var blocker: ChatterBlocker
    let configManager: ConfigManager
    let onSave: () -> Void

    @State private var showingAddKey = false
    @State private var newKeyCode: CGKeyCode?
    @State private var isListeningForKey = false
    @State private var newKeyThreshold: UInt64 = 100
    @State private var eventMonitor: Any?
    @State private var settingsSaved = false

    var body: some View {
        TabView {
            // Main Settings Tab
            mainSettingsTab
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }

            // Key Configuration Tab
            keyConfigurationTab
                .tabItem {
                    Label("Keys", systemImage: "keyboard")
                }

            // Statistics Tab
            statisticsTab
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar")
                }

            // Chatter Log Tab
            ChatterLogView(blocker: blocker)
                .tabItem {
                    Label("Log", systemImage: "list.bullet.rectangle")
                }
        }
        .frame(minWidth: 600, idealWidth: 700, maxWidth: .infinity,
               minHeight: 500, idealHeight: 600, maxHeight: .infinity)
        .onChange(of: blocker.isEnabled) { onSave() }
        .onChange(of: blocker.globalThreshold) { onSave() }
    }

    // MARK: - Main Settings Tab

    private var mainSettingsTab: some View {
        Form {
            Section {
                Toggle("Enable Chatter Blocking", isOn: $blocker.isEnabled)
                    .toggleStyle(.switch)

                HStack {
                    Text("Global Threshold:")
                    Spacer()
                    Text("\(blocker.globalThreshold) ms")
                        .foregroundColor(.secondary)
                }

                Slider(value: Binding(
                    get: { Double(blocker.globalThreshold) },
                    set: { blocker.globalThreshold = UInt64($0) }
                ), in: 0...500, step: 10)
                .disabled(!blocker.isEnabled)

                Text("Time window to block repeated keypresses")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Advanced") {
                HStack {
                    Text("Minimum Chatter Time:")
                    Spacer()
                    TextField("ms", value: $blocker.minimumChatterTime, format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                    Text("ms")
                        .foregroundColor(.secondary)
                }

                Toggle("Measure from key release", isOn: $blocker.measureFromRelease)
                    .toggleStyle(.switch)

                Text("Set minimum time to ignore very fast inputs (0 = disabled)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                HStack {
                    Button(action: {
                        onSave()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            settingsSaved = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                settingsSaved = false
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            if settingsSaved {
                                Image(systemName: "checkmark.circle")
                                    .transition(.scale.combined(with: .opacity))
                            }
                            Text(settingsSaved ? "Saved!" : "Save Settings")
                        }
                        .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(settingsSaved ? .green : .accentColor)

                    Spacer()

                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Key Configuration Tab

    private var keyConfigurationTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Per-Key Thresholds")
                    .font(.headline)

                Spacer()

                Button("Add Key...") {
                    showingAddKey = true
                }
                .buttonStyle(.bordered)
                .sheet(isPresented: $showingAddKey) {
                    addKeySheet
                }
            }
            .padding()

            Divider()

            let customThresholds = blocker.getCustomThresholds()

            if customThresholds.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No custom key thresholds configured")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Use global threshold for all keys")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(customThresholds.keys.sorted()), id: \.self) { keyCode in
                        HStack {
                            Text(KeyCodeMapper.keyName(for: keyCode))
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 120, alignment: .leading)

                            TextField("Threshold",
                                value: Binding(
                                    get: { customThresholds[keyCode] ?? 100 },
                                    set: { blocker.setThreshold($0, for: keyCode); onSave() }
                                ),
                                format: .number
                            )
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)

                            Text("ms")
                                .foregroundColor(.secondary)

                            Spacer()

                            Button(role: .destructive) {
                                blocker.removeThreshold(for: keyCode)
                                onSave()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - Add Key Sheet

    private var addKeySheet: some View {
        VStack(spacing: 20) {
            Text("Press any key to add custom threshold")
                .font(.headline)

            if isListeningForKey {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Listening for key press...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if let keyCode = newKeyCode {
                VStack(spacing: 12) {
                    Text("Key: \(KeyCodeMapper.keyName(for: keyCode))")
                        .font(.title2)
                        .fontDesign(.monospaced)

                    HStack {
                        Text("Threshold:")
                        TextField("ms", value: $newKeyThreshold, format: .number)
                            .frame(width: 60)
                        Text("ms")
                    }

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            cleanupKeyListener()
                            showingAddKey = false
                            newKeyCode = nil
                            newKeyThreshold = 100
                        }
                        .buttonStyle(.bordered)

                        Button("Add") {
                            blocker.setThreshold(newKeyThreshold, for: keyCode)
                            onSave()
                            cleanupKeyListener()
                            showingAddKey = false
                            newKeyCode = nil
                            newKeyThreshold = 100
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .padding(40)
        .frame(width: 350, height: 200)
        .onAppear {
            startKeyListener()
        }
        .onDisappear {
            cleanupKeyListener()
        }
    }

    // MARK: - Key Listener Helpers

    private func startKeyListener() {
        isListeningForKey = true
        newKeyCode = nil

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Capture the key code
            let keyCode = CGKeyCode(event.keyCode)

            // Allow ESC to cancel
            if keyCode == 53 { // ESC key
                cleanupKeyListener()
                showingAddKey = false
                return nil
            }

            // Store the captured key
            newKeyCode = keyCode
            isListeningForKey = false

            // Remove the event monitor after capturing
            cleanupKeyListener()

            // Block this event from propagating
            return nil
        }
    }

    private func cleanupKeyListener() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isListeningForKey = false
    }

    // MARK: - Statistics Tab

    private var sortedStatistics: [(key: CGKeyCode, value: (presses: Int, chatters: Int))] {
        // Sort statistics: Most blocked keys appear at the top
        // Primary sort: by blocked count (descending)
        // Secondary sort: by key code (ascending) for ties
        return blocker.statistics.sorted { first, second in
            if first.value.chatters != second.value.chatters {
                return first.value.chatters > second.value.chatters
            }
            return first.key < second.key
        }
    }

    private var statisticsTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Statistics")
                    .font(.headline)

                Spacer()

                Button("Reset") {
                    blocker.resetStatistics()
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            if blocker.statistics.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No statistics yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sortedStatistics, id: \.key) { keyCode, stats in
                        HStack {
                            Text(KeyCodeMapper.keyName(for: keyCode))
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 120, alignment: .leading)

                            Spacer()

                            VStack(alignment: .trailing) {
                                Text("Presses: \(stats.presses)")
                                    .font(.caption)
                                Text("Blocked: \(stats.chatters)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }

                            if stats.presses > 0 {
                                let rate = Double(stats.chatters) / Double(stats.presses) * 100
                                Text(String(format: "%.1f%%", rate))
                                    .font(.caption)
                                    .foregroundColor(rate > 10 ? .red : .secondary)
                                    .frame(width: 50, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - Reset to Defaults

    private func resetToDefaults() {
        blocker.isEnabled = false
        blocker.globalThreshold = 100
        blocker.minimumChatterTime = 0
        blocker.measureFromRelease = false
        blocker.resetTimingData()
        onSave()
    }
}
