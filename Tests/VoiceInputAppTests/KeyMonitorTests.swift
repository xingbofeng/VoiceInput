import CoreGraphics
import XCTest
@testable import VoiceInputApp

final class KeyMonitorTests: XCTestCase {
    func testRightCommandTransitionsProduceOnePressAndOneRelease() {
        var state = RightCommandKeyState()

        XCTAssertEqual(state.transition(keyCode: 54), .pressed)
        XCTAssertEqual(state.transition(keyCode: 54), .released)
    }

    func testLeftCommandAndOtherModifierKeysAreIgnored() {
        var state = RightCommandKeyState()

        XCTAssertNil(state.transition(keyCode: 55))
        XCTAssertNil(state.transition(keyCode: 56))
        XCTAssertFalse(state.isPressed)
    }

    func testResetAllowsNextRightCommandEventToPress() {
        var state = RightCommandKeyState()

        XCTAssertEqual(state.transition(keyCode: 54), .pressed)
        state.reset()
        XCTAssertEqual(state.transition(keyCode: 54), .pressed)
    }
}
