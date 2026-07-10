//
//  DebounceApp.swift
//  Debounce
//
//  Created by Timo Leisengang on 07.10.25.
//

import SwiftUI
import UserNotifications

@main
struct DebounceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    let chatterBlocker = ChatterBlocker()
    let configManager = ConfigManager()
    var eventInterceptor: EventInterceptor?
    private var statisticsSaveTimer: Timer?
    private var iconFlashTimer: Timer?
    private var statusMenuItem: NSMenuItem?
    private var toggleMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar app only)
        NSApp.setActivationPolicy(.accessory)

        // Load saved settings and statistics
        configManager.loadSettings(into: chatterBlocker)
        configManager.loadStatistics(into: chatterBlocker)

        // Create menu bar item
        setupMenuBar()

        // Set up event interceptor
        eventInterceptor = EventInterceptor(chatterBlocker: chatterBlocker)

        eventInterceptor?.onTapDied = { [weak self] in
            self?.handleTapDied()
        }

        chatterBlocker.onChatterBlocked = { [weak self] in
            self?.flashMenuBarIcon()
        }

        if chatterBlocker.isEnabled {
            startBlocking()
        }

        // Save statistics periodically (every 30 seconds)
        statisticsSaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.configManager.saveStatistics(from: self.chatterBlocker)
        }

        configManager.hasLaunchedBefore = true
    }

    func applicationWillTerminate(_ notification: Notification) {
        configManager.saveStatistics(from: chatterBlocker)
        stopBlocking()
    }

    // MARK: - Menu Bar

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Debounce")?
                .withSymbolConfiguration(config)
            button.action = #selector(statusBarButtonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        updateMenuBarIcon()
        createMenu()
    }

    func createMenu() {
        let menu = NSMenu()

        // Status with colored text
        let item = NSMenuItem()
        item.isEnabled = false
        statusMenuItem = item
        menu.addItem(item)

        menu.addItem(NSMenuItem.separator())

        // Toggle Enable/Disable
        let toggle = NSMenuItem(title: "", action: #selector(toggleBlocking), keyEquivalent: "e")
        toggleMenuItem = toggle
        menu.addItem(toggle)

        menu.addItem(NSMenuItem.separator())

        // Open Settings
        menu.addItem(NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))

        menu.addItem(NSMenuItem.separator())

        // Quit
        menu.addItem(NSMenuItem(
            title: "Quit Debounce",
            action: #selector(quitApp),
            keyEquivalent: "q"
        ))

        self.statusItem?.menu = menu
        updateMenu()
    }

    func updateMenu() {
        let isEnabled = chatterBlocker.isEnabled
        let statusTitle = isEnabled ? "Enabled" : "Disabled"
        let statusColor: NSColor = isEnabled ? .systemGreen : .secondaryLabelColor
        statusMenuItem?.attributedTitle = NSAttributedString(string: statusTitle, attributes: [
            .foregroundColor: statusColor,
            .font: NSFont.menuFont(ofSize: 0)
        ])
        toggleMenuItem?.title = isEnabled ? "Disable" : "Enable"
    }

    @objc func statusBarButtonClicked() {
        updateMenu()
    }

    @objc func toggleBlocking() {
        chatterBlocker.isEnabled.toggle()

        if chatterBlocker.isEnabled {
            startBlocking()
        } else {
            stopBlocking()
        }

        configManager.saveSettings(from: chatterBlocker)
        updateMenuBarIcon()
        updateMenu()
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView(
                blocker: chatterBlocker,
                configManager: configManager,
                onToggleBlocking: { [weak self] enabled in
                    guard let self else { return }
                    if enabled {
                        self.startBlocking()
                    } else {
                        self.stopBlocking()
                    }
                    self.configManager.saveSettings(from: self.chatterBlocker)
                    self.updateMenuBarIcon()
                    self.updateMenu()
                }
            )

            let hostingController = NSHostingController(rootView: settingsView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Debounce — Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 600, height: 500))
            window.center()

            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        configManager.saveStatistics(from: chatterBlocker)
        stopBlocking()
        NSApp.terminate(nil)
    }

    func startBlocking() {
        if eventInterceptor?.start() != .started {
            chatterBlocker.isEnabled = false
            updateMenuBarIcon()
        }
    }

    func stopBlocking() {
        eventInterceptor?.stop()
        chatterBlocker.resetTimingData()
    }

    // MARK: - Menu Bar Icon

    func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        if chatterBlocker.isEnabled {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Debounce — Enabled")?
                .withSymbolConfiguration(config)
        } else {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Debounce — Disabled")?
                .withSymbolConfiguration(config)
            button.appearsDisabled = true
        }
        if chatterBlocker.isEnabled {
            button.appearsDisabled = false
        }
    }

    private func flashMenuBarIcon() {
        guard let button = statusItem?.button else { return }

        // Debounce rapid flashes
        iconFlashTimer?.invalidate()

        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        button.image = NSImage(systemSymbolName: "keyboard.badge.ellipsis", accessibilityDescription: "Chatter blocked")?
            .withSymbolConfiguration(config)

        iconFlashTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.updateMenuBarIcon()
        }
    }

    // MARK: - Event Tap Death

    private func handleTapDied() {
        chatterBlocker.isEnabled = false
        updateMenuBarIcon()
        updateMenu()

        // Update the icon to indicate error
        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            button.image = NSImage(systemSymbolName: "keyboard.badge.exclamationmark", accessibilityDescription: "Debounce — Error")?
                .withSymbolConfiguration(config)
        }

        // Show notification
        let content = UNMutableNotificationContent()
        content.title = "Chatter blocking stopped"
        content.body = "The keyboard event monitor was terminated. Re-enable from the menu bar."
        content.sound = .default

        requestNotificationAuthorization { granted in
            guard granted else { return }
            let request = UNNotificationRequest(identifier: "tapDied", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func requestNotificationAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            completion(granted)
        }
    }

}
