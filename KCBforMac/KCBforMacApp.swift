//
//  KCBforMacApp.swift
//  KCBforMac
//
//  Created by Timo Leisengang on 07.10.25.
//

import SwiftUI

@main
struct KCBforMacApp: App {
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar app only)
        NSApp.setActivationPolicy(.accessory)

        // Load saved settings
        configManager.loadSettings(into: chatterBlocker)

        // Create menu bar item
        setupMenuBar()

        // Start event interceptor
        eventInterceptor = EventInterceptor(chatterBlocker: chatterBlocker)

        if chatterBlocker.isEnabled {
            startBlocking()
        }
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KCBforMac")
            button.action = #selector(statusBarButtonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        updateMenuBarIcon()
        createMenu()
    }

    func createMenu() {
        let menu = NSMenu()

        // Status
        let statusMenuItem = NSMenuItem(title: chatterBlocker.isEnabled ? "✓ Enabled" : "✗ Disabled", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Toggle Enable/Disable
        let toggleItem = NSMenuItem(
            title: chatterBlocker.isEnabled ? "Disable" : "Enable",
            action: #selector(toggleBlocking),
            keyEquivalent: "e"
        )
        menu.addItem(toggleItem)

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
            title: "Quit KCBforMac",
            action: #selector(quitApp),
            keyEquivalent: "q"
        ))

        statusItem?.menu = menu
    }

    @objc func statusBarButtonClicked() {
        // Recreate menu each time to update status
        createMenu()
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
        createMenu()
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView(
                blocker: chatterBlocker,
                configManager: configManager,
                onSave: { [weak self] in
                    self?.configManager.saveSettings(from: self!.chatterBlocker)
                    self?.updateMenuBarIcon()
                }
            )

            let hostingController = NSHostingController(rootView: settingsView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "KCBforMac Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 550, height: 450))
            window.center()

            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        stopBlocking()
        NSApp.terminate(nil)
    }

    func startBlocking() {
        if eventInterceptor?.start() == false {
            // Failed to start, likely no permissions
            chatterBlocker.isEnabled = false
            updateMenuBarIcon()
        }
    }

    func stopBlocking() {
        eventInterceptor?.stop()
        chatterBlocker.resetTimingData()
    }

    func updateMenuBarIcon() {
        if let button = statusItem?.button {
            // Change icon based on state
            if chatterBlocker.isEnabled {
                button.image = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: "KCBforMac Enabled")
            } else {
                button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KCBforMac Disabled")
            }
        }
    }
}
