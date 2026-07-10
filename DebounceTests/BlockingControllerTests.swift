import XCTest
@testable import Debounce

private final class StubEventInterceptor: EventIntercepting {
    var onTapDied: (() -> Void)?
    var results: [EventInterceptorStartResult]
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(results: [EventInterceptorStartResult]) {
        self.results = results
    }

    func start() -> EventInterceptorStartResult {
        startCount += 1
        return results.removeFirst()
    }

    func stop() {
        stopCount += 1
    }
}

@MainActor
final class BlockingControllerTests: XCTestCase {
    func testPermissionFailureCreatesPendingEnableWithoutClaimingEnabled() {
        let blocker = ChatterBlocker()
        let interceptor = StubEventInterceptor(results: [.accessibilityPermissionRequired])
        var persistedStates: [Bool] = []
        let controller = BlockingController(
            blocker: blocker,
            interceptor: interceptor,
            persist: { persistedStates.append($0.isEnabled) }
        )

        XCTAssertEqual(controller.setEnabled(true), .permissionRequired)

        XCTAssertFalse(blocker.isEnabled)
        XCTAssertTrue(controller.pendingPermissionEnable)
        XCTAssertEqual(interceptor.startCount, 1)
        XCTAssertEqual(interceptor.stopCount, 0)
        XCTAssertEqual(persistedStates.last, false)
    }

    func testRetryAfterPermissionGrantStartsAndPersistsEnabledState() {
        let blocker = ChatterBlocker()
        let interceptor = StubEventInterceptor(results: [
            .accessibilityPermissionRequired,
            .started
        ])
        var persistedStates: [Bool] = []
        let controller = BlockingController(
            blocker: blocker,
            interceptor: interceptor,
            persist: { persistedStates.append($0.isEnabled) }
        )

        XCTAssertEqual(controller.setEnabled(true), .permissionRequired)
        XCTAssertEqual(controller.retryPendingPermission(), .enabled)

        XCTAssertTrue(blocker.isEnabled)
        XCTAssertFalse(controller.pendingPermissionEnable)
        XCTAssertEqual(interceptor.startCount, 2)
        XCTAssertEqual(interceptor.stopCount, 0)
        XCTAssertEqual(persistedStates, [false, true])
    }

    func testTapFailureDisablesAndPersistsDisabledState() {
        let blocker = ChatterBlocker()
        blocker.isEnabled = true
        let interceptor = StubEventInterceptor(results: [.eventTapCreationFailed])
        var persistedStates: [Bool] = []
        let controller = BlockingController(
            blocker: blocker,
            interceptor: interceptor,
            persist: { persistedStates.append($0.isEnabled) }
        )

        XCTAssertEqual(controller.setEnabled(true), .eventTapCreationFailed)

        XCTAssertFalse(blocker.isEnabled)
        XCTAssertFalse(controller.pendingPermissionEnable)
        XCTAssertEqual(interceptor.startCount, 1)
        XCTAssertEqual(interceptor.stopCount, 0)
        XCTAssertEqual(persistedStates.last, false)
    }

    func testRunLoopSourceFailureDisablesAndPersistsDisabledState() {
        let blocker = ChatterBlocker()
        blocker.isEnabled = true
        let interceptor = StubEventInterceptor(results: [.runLoopSourceCreationFailed])
        var persistedStates: [Bool] = []
        let controller = BlockingController(
            blocker: blocker,
            interceptor: interceptor,
            persist: { persistedStates.append($0.isEnabled) }
        )

        XCTAssertEqual(controller.setEnabled(true), .runLoopSourceCreationFailed)

        XCTAssertFalse(blocker.isEnabled)
        XCTAssertFalse(controller.pendingPermissionEnable)
        XCTAssertEqual(interceptor.startCount, 1)
        XCTAssertEqual(interceptor.stopCount, 0)
        XCTAssertEqual(persistedStates.last, false)
    }

    func testExplicitDisableClearsPendingPermissionAndStopsInterceptor() {
        let blocker = ChatterBlocker()
        let interceptor = StubEventInterceptor(results: [.accessibilityPermissionRequired])
        var persistedStates: [Bool] = []
        let controller = BlockingController(
            blocker: blocker,
            interceptor: interceptor,
            persist: { persistedStates.append($0.isEnabled) }
        )
        XCTAssertEqual(controller.setEnabled(true), .permissionRequired)

        XCTAssertEqual(controller.setEnabled(false), .disabled)

        XCTAssertFalse(blocker.isEnabled)
        XCTAssertFalse(controller.pendingPermissionEnable)
        XCTAssertEqual(interceptor.startCount, 1)
        XCTAssertEqual(interceptor.stopCount, 1)
        XCTAssertEqual(persistedStates.last, false)
    }
}
