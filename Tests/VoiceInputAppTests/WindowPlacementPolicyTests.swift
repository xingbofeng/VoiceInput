import AppKit
import XCTest
@testable import VoiceInputApp

final class WindowPlacementPolicyTests: XCTestCase {
    func testCenteredFrameUsesVisibleFrameCenter() {
        let frame = WindowPlacementPolicy.centeredFrame(
            windowSize: NSSize(width: 600, height: 400),
            visibleFrame: NSRect(x: 100, y: 200, width: 1_200, height: 800)
        )

        XCTAssertEqual(frame.origin.x, 400)
        XCTAssertEqual(frame.origin.y, 400)
        XCTAssertEqual(frame.size.width, 600)
        XCTAssertEqual(frame.size.height, 400)
    }
}
