import AppKit
import XCTest
@testable import VoiceInputApp

final class PasteboardSnapshotTests: XCTestCase {
    func testSnapshotPreservesEveryItemAndDeclaredType() throws {
        let customType = NSPasteboard.PasteboardType("dev.voiceinput.custom")
        let first = NSPasteboardItem()
        first.setString("plain", forType: .string)
        first.setData(Data([0x01, 0x02]), forType: customType)

        let second = NSPasteboardItem()
        second.setData(Data("rich".utf8), forType: .rtf)

        let snapshot = PasteboardSnapshot(items: [first, second])

        XCTAssertEqual(snapshot.items.count, 2)
        XCTAssertEqual(snapshot.items[0].representations[.string], Data("plain".utf8))
        XCTAssertEqual(snapshot.items[0].representations[customType], Data([0x01, 0x02]))
        XCTAssertEqual(snapshot.items[1].representations[.rtf], Data("rich".utf8))
    }

    func testSnapshotRecreatesMultiplePasteboardItems() {
        let snapshot = PasteboardSnapshot(
            archivedItems: [
                [.string: Data("first".utf8)],
                [.string: Data("second".utf8)],
            ]
        )

        let restored = snapshot.makePasteboardItems()

        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored[0].string(forType: .string), "first")
        XCTAssertEqual(restored[1].string(forType: .string), "second")
    }
}
