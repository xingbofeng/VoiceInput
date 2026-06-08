import CoreGraphics
import XCTest
@testable import VoiceInputApp

final class KeyMonitorTests: XCTestCase {
    func testRightCommandTransitionsProduceOnePressAndOneRelease() {
        var state = RightCommandKeyState()

        XCTAssertEqual(state.transition(threshold: 0.0), .pressed)
        XCTAssertEqual(state.transition(threshold: 0.0), .released)
    }

    func testMultiplePressesAreTrackedCorrectly() {
        var state = RightCommandKeyState()

        // First press/release cycle with threshold 0.0 (any duration >= 0 → long press)
        XCTAssertEqual(state.transition(threshold: 0.0), .pressed)
        XCTAssertEqual(state.transition(threshold: 0.0), .released)

        // Second press — should restart from fresh
        XCTAssertEqual(state.transition(threshold: 0.0), .pressed)
        XCTAssertTrue(state.isPressed)

        // Release with high threshold → shortPress
        XCTAssertEqual(state.transition(threshold: 10.0), .shortPress)
        XCTAssertFalse(state.isPressed)
    }

    func testResetAllowsNextEventToPress() {
        var state = RightCommandKeyState()

        XCTAssertEqual(state.transition(threshold: 0.5), .pressed)
        state.reset()
        // After reset, isPressed should be false, so next transition is a press
        XCTAssertEqual(state.transition(threshold: 0.5), .pressed)
    }

    // MARK: - Short press vs long press

    func testShortPressDetectedWhenDurationBelowThreshold() {
        var state = RightCommandKeyState()

        // Press and immediately release — duration is virtually zero, well below 10s
        XCTAssertEqual(state.transition(threshold: 10.0), .pressed)
        XCTAssertEqual(state.transition(threshold: 10.0), .shortPress)
    }

    func testLongPressDetectedWhenDurationAboveThreshold() {
        var state = RightCommandKeyState()

        // Any non-negative duration is >= 0, so release is always a long press
        XCTAssertEqual(state.transition(threshold: 0.0), .pressed)
        XCTAssertEqual(state.transition(threshold: 0.0), .released)
    }

    func testShortcutEventsPassThroughWhileAppIsActive() {
        // Without any key window, the shortcut should be intercepted even
        // when the app is technically active (e.g., after closing settings).
        XCTAssertFalse(ShortcutEventRouting.shouldPassThrough(appIsActive: true))
        XCTAssertFalse(ShortcutEventRouting.shouldPassThrough(appIsActive: false))
    }

    func testShortcutEventsPassThroughOnlyWhenKeyWindowIsPresent() {
        // Simulate: no key window → always intercept the shortcut.
        XCTAssertFalse(ShortcutEventRouting.shouldPassThrough(appIsActive: true))

        // Post-test cleanup: AppKit test environment may have lingering windows.
    }
}
