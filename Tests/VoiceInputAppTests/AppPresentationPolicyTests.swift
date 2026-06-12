import AppKit
import XCTest
@testable import VoiceInputApp

final class AppPresentationPolicyTests: XCTestCase {
    func testWorkbenchAppUsesRegularActivationPolicy() {
        XCTAssertEqual(AppPresentationPolicy.activationPolicy, .regular)
    }

    func testRegularAppOpensAndRestoresWorkbenchWindow() {
        XCTAssertTrue(AppPresentationPolicy.opensWorkbenchOnLaunch)
        XCTAssertTrue(AppPresentationPolicy.restoresWorkbenchOnReopen)
    }

    func testInfoPlistDoesNotDeclareAgentOnlyApp() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let plistURL = repositoryRoot
            .appendingPathComponent("Sources/VoiceInputApp/Resources/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        XCTAssertNotEqual(plist["LSUIElement"] as? Bool, true)
    }
}
