//
//  SettingsView.swift
//  Debounce
//
//  Created by Timo Leisengang on 07.10.25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var blocker: ChatterBlocker
    let configManager: ConfigManager
    let onToggleBlocking: (Bool) -> Void

    @State private var showingAddKey = false
    @State private var newKeyCode: CGKeyCode?
    @State private var isListeningForKey = false
    @State private var newKeyThreshold: UInt64 = 100
    @State private var eventMonitor: Any?
    @State private var showResetConfirmation = false
    @State private var launchAtLogin: Bool = false
    @State private var launchAtLoginError: String?
    @State private var launchAtLoginApprovalRequired = false
    @State private var showDuplicateKeyAlert = false
    @State private var duplicateKeyCode: CGKeyCode?
    @State private var keyCaptured = false
    @State private var statisticsSearch = ""

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
        .onChange(of: blocker.isEnabled) { _, newValue in
            onToggleBlocking(newValue)
        }
        .onChange(of: blocker.globalThreshold) { save() }
        .onChange(of: blocker.minimumChatterTime) { save() }
        .onChange(of: blocker.measureFromRelease) { save() }
    }

    private func save() {
        configManager.saveSettings(from: blocker)
    }

    // MARK: - Main Settings Tab

    private var mainSettingsTab: some View {
        Form {
            Section {
                Toggle("Enable Chatter Blocking", isOn: $blocker.isEnabled)
                    .toggleStyle(.switch)

                LabeledContent("Global Threshold:") {
                    HStack(spacing: 4) {
                        TextField("", value: $blocker.globalThreshold, format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                        Text("ms")
                            .foregroundColor(.secondary)
                    }
                    .fixedSize()
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
                LabeledContent("Minimum Chatter Time:") {
                    HStack(spacing: 4) {
                        TextField("", value: $blocker.minimumChatterTime, format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                        Text("ms")
                            .foregroundColor(.secondary)
                    }
                    .fixedSize()
                }

                Toggle("Measure from key release", isOn: $blocker.measureFromRelease)
                    .toggleStyle(.switch)

                Text("Events faster than this are ignored by chatter detection (0 = disabled)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin },
                    set: updateLaunchAtLogin
                ))
                    .toggleStyle(.switch)
            }

            Section {
                Button("Reset to Defaults") {
                    showResetConfirmation = true
                }
                .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            launchAtLogin = configManager.getStartAtLogin()
        }
        .alert("Reset to Defaults?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetToDefaults()
            }
        } message: {
            Text("This will reset all thresholds and disable chatter blocking.")
        }
        .alert("Unable to Change Login Setting", isPresented: Binding(
            get: { launchAtLoginError != nil },
            set: { isPresented in
                if !isPresented {
                    dismissLaunchAtLoginError()
                }
            }
        )) {
            if launchAtLoginApprovalRequired {
                Button("Open Login Items Settings") {
                    configManager.openLoginItemsSettings()
                    dismissLaunchAtLoginError()
                }
            }
            Button("OK") {
                dismissLaunchAtLoginError()
            }
        } message: {
            Text(launchAtLoginError ?? "An unknown error occurred.")
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            try configManager.setStartAtLogin(enabled)
            launchAtLogin = configManager.getStartAtLogin()
        } catch {
            launchAtLogin = configManager.getStartAtLogin()
            launchAtLoginApprovalRequired = error as? LaunchAtLoginError == .approvalRequired
            launchAtLoginError = error.localizedDescription
        }
    }

    private func dismissLaunchAtLoginError() {
        launchAtLoginError = nil
        launchAtLoginApprovalRequired = false
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
                                    set: { blocker.setThreshold($0, for: keyCode); save() }
                                ),
                                format: .number
                            )
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)

                            Text("ms")
                                .foregroundColor(.secondary)

                            Spacer()

                            Button(role: .destructive) {
                                blocker.removeThreshold(for: keyCode)
                                save()
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
                    Text(KeyCodeMapper.keyName(for: keyCode))
                        .font(.title2)
                        .fontDesign(.monospaced)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
                        .scaleEffect(keyCaptured ? 1.0 : 0.8)
                        .animation(.spring(duration: 0.3), value: keyCaptured)

                    HStack {
                        Text("Threshold:")
                        TextField("ms", value: $newKeyThreshold, format: .number)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                        Text("ms")
                    }

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            dismissAddKeySheet()
                        }
                        .buttonStyle(.bordered)

                        Button("Add") {
                            addOrUpdateKey(keyCode: keyCode)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .padding(40)
        .frame(width: 400, height: 220)
        .onAppear {
            startKeyListener()
        }
        .onDisappear {
            cleanupKeyListener()
        }
        .alert("Key already configured", isPresented: $showDuplicateKeyAlert) {
            Button("Update") {
                if let keyCode = duplicateKeyCode {
                    blocker.setThreshold(newKeyThreshold, for: keyCode)
                    save()
                }
                dismissAddKeySheet()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let keyCode = duplicateKeyCode {
                Text("\(KeyCodeMapper.keyName(for: keyCode)) already has a custom threshold. Update it to \(newKeyThreshold) ms?")
            }
        }
    }

    private func addOrUpdateKey(keyCode: CGKeyCode) {
        let existingThresholds = blocker.getCustomThresholds()
        if existingThresholds[keyCode] != nil {
            duplicateKeyCode = keyCode
            showDuplicateKeyAlert = true
        } else {
            blocker.setThreshold(newKeyThreshold, for: keyCode)
            save()
            dismissAddKeySheet()
        }
    }

    private func dismissAddKeySheet() {
        cleanupKeyListener()
        showingAddKey = false
        newKeyCode = nil
        newKeyThreshold = 100
        keyCaptured = false
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
            keyCaptured = true

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

    private var filteredStatistics: [(key: CGKeyCode, value: (presses: Int, chatters: Int))] {
        let sorted = blocker.statistics.sorted { first, second in
            if first.value.chatters != second.value.chatters {
                return first.value.chatters > second.value.chatters
            }
            return first.key < second.key
        }
        if statisticsSearch.isEmpty {
            return sorted
        }
        return sorted.filter { keyCode, _ in
            KeyCodeMapper.keyName(for: keyCode).localizedCaseInsensitiveContains(statisticsSearch)
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

            if blocker.statistics.count > 10 {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Filter keys...", text: $statisticsSearch)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

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
                    ForEach(filteredStatistics, id: \.key) { keyCode, stats in
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
        blocker.removeAllThresholds()
        blocker.resetTimingData()
        updateLaunchAtLogin(false)
        save()
    }
}
