import XCTest
@testable import Debounce

private final class StubPermissionChecker: AccessibilityPermissionChecking {
    var trusted: Bool

    init(trusted: Bool) {
        self.trusted = trusted
    }

    func isAccessibilityTrusted(prompt: Bool) -> Bool {
        trusted
    }
}

private final class StubEventTapDriver: EventTapDriving {
    let result: EventTapDriverStartResult
    private(set) var startCount = 0
    private(set) var stopCount = 0
    var onTapDied: (() -> Void)?

    init(result: EventTapDriverStartResult) {
        self.result = result
    }

    func start() -> EventTapDriverStartResult {
        startCount += 1
        return result
    }

    func stop() {
        stopCount += 1
    }
}

@MainActor
final class EventInterceptorTests: XCTestCase {
    func testMissingPermissionDoesNotAttemptTapCreation() {
        let driver = StubEventTapDriver(result: .started)
        let interceptor = EventInterceptor(
            chatterBlocker: ChatterBlocker(),
            permissionChecker: StubPermissionChecker(trusted: false),
            driver: driver
        )

        XCTAssertEqual(interceptor.start(), .accessibilityPermissionRequired)
        XCTAssertEqual(driver.startCount, 0)
    }

    func testMapsTapCreationFailure() {
        let interceptor = EventInterceptor(
            chatterBlocker: ChatterBlocker(),
            permissionChecker: StubPermissionChecker(trusted: true),
            driver: StubEventTapDriver(result: .tapCreationFailed)
        )

        XCTAssertEqual(interceptor.start(), .eventTapCreationFailed)
    }

    func testMapsRunLoopSourceFailure() {
        let interceptor = EventInterceptor(
            chatterBlocker: ChatterBlocker(),
            permissionChecker: StubPermissionChecker(trusted: true),
            driver: StubEventTapDriver(result: .runLoopSourceCreationFailed)
        )

        XCTAssertEqual(interceptor.start(), .runLoopSourceCreationFailed)
    }

    func testMapsSuccessfulStart() {
        let driver = StubEventTapDriver(result: .started)
        let interceptor = EventInterceptor(
            chatterBlocker: ChatterBlocker(),
            permissionChecker: StubPermissionChecker(trusted: true),
            driver: driver
        )

        XCTAssertEqual(interceptor.start(), .started)
        XCTAssertEqual(driver.startCount, 1)
    }

    func testForwardsTapDeathHandlerToDriver() {
        let driver = StubEventTapDriver(result: .started)
        let interceptor = EventInterceptor(
            chatterBlocker: ChatterBlocker(),
            permissionChecker: StubPermissionChecker(trusted: true),
            driver: driver
        )
        var handlerCalled = false

        interceptor.onTapDied = {
            handlerCalled = true
        }
        driver.onTapDied?()

        XCTAssertTrue(handlerCalled)
    }

    func testTrustLossStopsExistingDriverWithoutRestarting() {
        let permissionChecker = StubPermissionChecker(trusted: true)
        let driver = StubEventTapDriver(result: .started)
        let interceptor = EventInterceptor(
            chatterBlocker: ChatterBlocker(),
            permissionChecker: permissionChecker,
            driver: driver
        )

        XCTAssertEqual(interceptor.start(), .started)
        permissionChecker.trusted = false

        XCTAssertEqual(interceptor.start(), .accessibilityPermissionRequired)
        XCTAssertEqual(driver.startCount, 1)
        XCTAssertEqual(driver.stopCount, 2)
    }

    func testEventTapTeardownInvalidatesTapBeforeRemovingSourceAndClearingReferences() {
        var actions: [String] = []

        EventTapTeardown.perform(
            disableTap: { actions.append("disableTap") },
            invalidateTap: { actions.append("invalidateTap") },
            removeRunLoopSource: { actions.append("removeRunLoopSource") },
            clearRunLoopSource: { actions.append("clearRunLoopSource") },
            clearTap: { actions.append("clearTap") }
        )

        XCTAssertEqual(actions, [
            "disableTap",
            "invalidateTap",
            "removeRunLoopSource",
            "clearRunLoopSource",
            "clearTap"
        ])
    }
}
