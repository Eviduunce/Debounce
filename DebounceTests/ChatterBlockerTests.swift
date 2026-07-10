import CoreGraphics
import XCTest
@testable import Debounce

final class ChatterBlockerTests: XCTestCase {
    private let keyA = CGKeyCode(0)

    func testAllowsEventsBelowMinimumChatterTime() {
        var now: UInt64 = 1_000
        let blocker = ChatterBlocker(now: { now })
        blocker.isEnabled = true
        blocker.globalThreshold = 100
        blocker.minimumChatterTime = 10

        XCTAssertTrue(blocker.shouldAllowKeyDown(keyCode: keyA))
        XCTAssertTrue(blocker.shouldAllowKeyUp(keyCode: keyA))

        now = 1_005

        XCTAssertTrue(blocker.shouldAllowKeyDown(keyCode: keyA))
    }

    func testBlocksRepeatedPressWithinThreshold() {
        var now: UInt64 = 1_000
        let blocker = ChatterBlocker(now: { now })
        blocker.isEnabled = true
        blocker.globalThreshold = 100

        XCTAssertTrue(blocker.shouldAllowKeyDown(keyCode: keyA))
        XCTAssertTrue(blocker.shouldAllowKeyUp(keyCode: keyA))

        now = 1_050

        XCTAssertFalse(blocker.shouldAllowKeyDown(keyCode: keyA))
    }

    func testAllowsRepeatedPressAfterThreshold() {
        var now: UInt64 = 1_000
        let blocker = ChatterBlocker(now: { now })
        blocker.isEnabled = true
        blocker.globalThreshold = 100

        XCTAssertTrue(blocker.shouldAllowKeyDown(keyCode: keyA))
        XCTAssertTrue(blocker.shouldAllowKeyUp(keyCode: keyA))

        now = 1_100

        XCTAssertTrue(blocker.shouldAllowKeyDown(keyCode: keyA))
    }
}
