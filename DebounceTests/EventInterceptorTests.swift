import XCTest
@testable import Debounce

private struct StubPermissionChecker: AccessibilityPermissionChecking {
    let trusted: Bool

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
}
