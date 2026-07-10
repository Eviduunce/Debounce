//
//  DebounceApp.swift
//  Debounce
//
//  Created by Timo Leisengang on 07.10.25.
//

import SwiftUI
import UserNotifications

protocol EventIntercepting: AnyObject {
    var onTapDied: (() -> Void)? { get set }
    func start() -> EventInterceptorStartResult
    func stop()
}

extension EventInterceptor: EventIntercepting {}

enum BlockingTransition: Equatable {
    case enabled
    case disabled
    case permissionRequired
    case eventTapCreationFailed
    case runLoopSourceCreationFailed
}

final class BlockingController {
    private let blocker: ChatterBlocker
    private let interceptor: EventIntercepting
    private let persist: (ChatterBlocker) -> Void

    private(set) var pendingPermissionEnable = false

    init(
        blocker: ChatterBlocker,
        interceptor: EventIntercepting,
        persist: @escaping (ChatterBlocker) -> Void
    ) {
        self.blocker = blocker
        self.interceptor = interceptor
        self.persist = persist
    }

    func setEnabled(_ enabled: Bool) -> BlockingTransition {
        guard enabled else {
            interceptor.stop()
            blocker.resetTimingData()
            blocker.isEnabled = false
            pendingPermissionEnable = false
            persist(blocker)
            return .disabled
        }

        let transition: BlockingTransition
        switch interceptor.start() {
        case .started:
            blocker.isEnabled = true
            pendingPermissionEnable = false
            transition = .enabled
        case .accessibilityPermissionRequired:
            blocker.isEnabled = false
            pendingPermissionEnable = true
            blocker.resetTimingData()
            transition = .permissionRequired
        case .eventTapCreationFailed:
            blocker.isEnabled = false
            pendingPermissionEnable = false
            blocker.resetTimingData()
            transition = .eventTapCreationFailed
        case .runLoopSourceCreationFailed:
            blocker.isEnabled = false
            pendingPermissionEnable = false
            blocker.resetTimingData()
            transition = .runLoopSourceCreationFailed
        }

        persist(blocker)
        return transition
    }

    func retryPendingPermission() -> BlockingTransition {
        guard pendingPermissionEnable else {
            return blocker.isEnabled ? .enabled : .disabled
        }
        return setEnabled(true)
    }
}

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
    private let permissionHelper = PermissionHelper()
    var eventInterceptor: EventInterceptor?
    private var blockingController: BlockingController?
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
        let eventInterceptor = EventInterceptor(chatterBlocker: chatterBlocker)
        self.eventInterceptor = eventInterceptor
        blockingController = BlockingController(
            blocker: chatterBlocker,
            interceptor: eventInterceptor,
            persist: { [weak self] blocker in
                self?.configManager.saveSettings(from: blocker)
            }
        )

        eventInterceptor.onTapDied = { [weak self] in
            self?.handleTapDied()
        }

        chatterBlocker.onChatterBlocked = { [weak self] in
            self?.flashMenuBarIcon()
        }

        if chatterBlocker.isEnabled {
            requestBlockingState(true)
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
        eventInterceptor?.stop()
        chatterBlocker.resetTimingData()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard blockingController?.pendingPermissionEnable == true else { return }
        retryPendingPermission()
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
        requestBlockingState(!chatterBlocker.isEnabled)
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView(
                blocker: chatterBlocker,
                configManager: configManager,
                onToggleBlocking: { [weak self] enabled in
                    self?.requestBlockingState(enabled)
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
        NSApp.terminate(nil)
    }

    private func requestBlockingState(_ enabled: Bool) {
        guard let blockingController else { return }
        let transition = blockingController.setEnabled(enabled)
        handleBlockingTransition(transition, presentPermissionAlert: true)
    }

    private func retryPendingPermission() {
        guard let blockingController else { return }
        let transition = blockingController.retryPendingPermission()
        handleBlockingTransition(transition, presentPermissionAlert: false)
    }

    private func handleBlockingTransition(
        _ transition: BlockingTransition,
        presentPermissionAlert: Bool
    ) {
        updateMenuBarIcon()
        updateMenu()

        switch transition {
        case .enabled, .disabled:
            break
        case .permissionRequired:
            if presentPermissionAlert {
                handlePermissionRequired()
            }
        case .eventTapCreationFailed:
            presentAlert(
                title: "Keyboard Monitor Could Not Start",
                message: "Debounce has Accessibility permission, but macOS could not create the keyboard event monitor. Try disabling and re-enabling Debounce."
            )
        case .runLoopSourceCreationFailed:
            presentAlert(
                title: "Keyboard Monitor Could Not Attach",
                message: "Debounce created the keyboard event monitor, but could not attach it to the app’s run loop. Quit and reopen Debounce, then try again."
            )
        }
    }

    private func handlePermissionRequired() {
        do {
            switch try permissionHelper.showPermissionAlert() {
            case .openSettings, .repairPermission:
                break
            case .cancel:
                cancelPendingPermissionEnable()
            }
        } catch {
            cancelPendingPermissionEnable()
            presentAlert(
                title: "Unable to Repair Accessibility Permission",
                message: error.localizedDescription
            )
        }
    }

    private func cancelPendingPermissionEnable() {
        guard let blockingController else { return }
        let transition = blockingController.setEnabled(false)
        handleBlockingTransition(transition, presentPermissionAlert: false)
    }

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
        if let blockingController {
            let transition = blockingController.setEnabled(false)
            handleBlockingTransition(transition, presentPermissionAlert: false)
        }

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
