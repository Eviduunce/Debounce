//
//  EventInterceptor.swift
//  Debounce
//
//  Created by Timo Leisengang on 07.10.25.
//

import Cocoa
import Carbon

enum EventTapDriverStartResult: Equatable {
    case started
    case tapCreationFailed
    case runLoopSourceCreationFailed
}

protocol EventTapDriving: AnyObject {
    var onTapDied: (() -> Void)? { get set }
    func start() -> EventTapDriverStartResult
    func stop()
}

enum EventInterceptorStartResult: Equatable {
    case started
    case accessibilityPermissionRequired
    case eventTapCreationFailed
    case runLoopSourceCreationFailed
}

enum EventTapTeardown {
    static func perform(
        disableTap: () -> Void,
        invalidateTap: () -> Void,
        removeRunLoopSource: () -> Void,
        clearRunLoopSource: () -> Void,
        clearTap: () -> Void
    ) {
        disableTap()
        invalidateTap()
        removeRunLoopSource()
        clearRunLoopSource()
        clearTap()
    }
}

/// Coordinates Accessibility permission checks with the event-tap driver.
final class EventInterceptor {
    let chatterBlocker: ChatterBlocker

    var onTapDied: (() -> Void)? {
        get { driver.onTapDied }
        set { driver.onTapDied = newValue }
    }

    private let permissionChecker: AccessibilityPermissionChecking
    private let driver: EventTapDriving

    init(
        chatterBlocker: ChatterBlocker,
        permissionChecker: AccessibilityPermissionChecking = PermissionHelper(),
        driver: EventTapDriving? = nil
    ) {
        self.chatterBlocker = chatterBlocker
        self.permissionChecker = permissionChecker
        self.driver = driver ?? CoreGraphicsEventTapDriver(chatterBlocker: chatterBlocker)
    }

    /// Start intercepting keyboard events.
    func start() -> EventInterceptorStartResult {
        driver.stop()

        guard permissionChecker.isAccessibilityTrusted(prompt: false) else {
            return .accessibilityPermissionRequired
        }

        switch driver.start() {
        case .started:
            return .started
        case .tapCreationFailed:
            return .eventTapCreationFailed
        case .runLoopSourceCreationFailed:
            return .runLoopSourceCreationFailed
        }
    }

    func stop() {
        driver.stop()
    }

    deinit {
        stop()
    }
}

/// Owns the CoreGraphics event tap and its run-loop source.
final class CoreGraphicsEventTapDriver: EventTapDriving {
    var onTapDied: (() -> Void)?

    fileprivate var eventTap: CFMachPort?
    fileprivate let chatterBlocker: ChatterBlocker
    private var runLoopSource: CFRunLoopSource?

    init(chatterBlocker: ChatterBlocker) {
        self.chatterBlocker = chatterBlocker
    }

    func start() -> EventTapDriverStartResult {
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventTapCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            return .tapCreationFailed
        }

        eventTap = tap

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            eventTap = nil
            return .runLoopSourceCreationFailed
        }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        return .started
    }

    func stop() {
        EventTapTeardown.perform(
            disableTap: {
                if let tap = self.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: false)
                }
            },
            invalidateTap: {
                if let tap = self.eventTap {
                    CFMachPortInvalidate(tap)
                }
            },
            removeRunLoopSource: {
                if let source = self.runLoopSource {
                    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
                }
            },
            clearRunLoopSource: {
                self.runLoopSource = nil
            },
            clearTap: {
                self.eventTap = nil
            }
        )
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
    // Handle event tap disabled (happens when user locks screen, etc).
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon {
            let driver = Unmanaged<CoreGraphicsEventTapDriver>.fromOpaque(refcon).takeUnretainedValue()
            if let tap = driver.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                if !CGEvent.tapIsEnabled(tap: tap) {
                    DispatchQueue.main.async {
                        driver.onTapDied?()
                    }
                }
            }
        }
        return Unmanaged.passUnretained(event)
    }

    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }

    let driver = Unmanaged<CoreGraphicsEventTapDriver>.fromOpaque(refcon).takeUnretainedValue()
    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

    switch type {
    case .keyDown:
        let shouldAllow = driver.chatterBlocker.shouldAllowKeyDown(keyCode: keyCode)
        return shouldAllow ? Unmanaged.passUnretained(event) : nil

    case .keyUp:
        let shouldAllow = driver.chatterBlocker.shouldAllowKeyUp(keyCode: keyCode)
        return shouldAllow ? Unmanaged.passUnretained(event) : nil

    default:
        return Unmanaged.passUnretained(event)
    }
}
