import XCTest
@testable import VoiceInputApp

final class AppThemeTests: XCTestCase {
    func testThemeUsesStableCompactRadiiAndSpacing() {
        XCTAssertEqual(AppTheme.Radius.card, 8)
        XCTAssertEqual(AppTheme.Radius.control, 6)
        XCTAssertEqual(AppTheme.Spacing.page, 28)
        XCTAssertEqual(AppTheme.Spacing.grid, 12)
    }
}
