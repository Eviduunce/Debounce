//
//  EventInterceptor.swift
//  Debounce
//
//  Created by Timo Leisengang on 07.10.25.
//

import Cocoa
import Carbon

/// Intercepts keyboard events using CGEventTap and passes them through the ChatterBlocker
class EventInterceptor {

    var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    let chatterBlocker: ChatterBlocker
    var onTapDied: (() -> Void)?

    init(chatterBlocker: ChatterBlocker) {
        self.chatterBlocker = chatterBlocker
    }

    /// Start intercepting keyboard events
    func start() -> Bool {
        guard PermissionHelper.ensureAccessibilityPermissions() else {
            return false
        }

        // Stop existing tap if any
        stop()

        // Create event tap
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventTapCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            return false
        }

        eventTap = tap

        // Create run loop source
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        guard let runLoopSource = runLoopSource else {
            return false
        }

        // Add to current run loop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

        // Enable the event tap
        CGEvent.tapEnable(tap: tap, enable: true)

        return true
    }

    /// Stop intercepting keyboard events
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }
    }

    deinit {
        stop()
    }
}

// MARK: - Event Tap Callback

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    // Handle event tap disabled (happens when user locks screen, etc)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon = refcon {
            let interceptor = Unmanaged<EventInterceptor>.fromOpaque(refcon).takeUnretainedValue()
            if let tap = interceptor.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                // Check if re-enable actually succeeded
                if !CGEvent.tapIsEnabled(tap: tap) {
                    DispatchQueue.main.async {
                        interceptor.onTapDied?()
                    }
                }
            }
        }
        return Unmanaged.passRetained(event)
    }

    guard let refcon = refcon else {
        return Unmanaged.passRetained(event)
    }

    let interceptor = Unmanaged<EventInterceptor>.fromOpaque(refcon).takeUnretainedValue()
    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

    switch type {
    case .keyDown:
        let shouldAllow = interceptor.chatterBlocker.shouldAllowKeyDown(keyCode: keyCode)
        return shouldAllow ? Unmanaged.passRetained(event) : nil

    case .keyUp:
        let shouldAllow = interceptor.chatterBlocker.shouldAllowKeyUp(keyCode: keyCode)
        return shouldAllow ? Unmanaged.passRetained(event) : nil

    default:
        return Unmanaged.passRetained(event)
    }
}
