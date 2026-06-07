import XCTest
@testable import VoiceInputApp

final class HelpExternalLinksTests: XCTestCase {
    func testProjectHomepageUsesLandingPage() {
        XCTAssertEqual(HelpExternalLinks.projectHomepage, "https://xingbofeng.github.io/VoiceInput/")
    }

    func testGitHubRepositoryRemainsSeparateEntry() {
        XCTAssertEqual(HelpExternalLinks.githubRepository, "https://github.com/xingbofeng/VoiceInput")
    }
}
