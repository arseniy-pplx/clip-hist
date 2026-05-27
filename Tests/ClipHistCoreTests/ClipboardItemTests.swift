import XCTest
@testable import ClipHistCore

final class ClipboardItemTests: XCTestCase {

    func testPreviewShortString() {
        let item = ClipboardItem(kind: .text, text: "hello world")
        XCTAssertEqual(item.preview, "hello world")
    }

    func testPreviewCollapsesWhitespace() {
        let item = ClipboardItem(kind: .text, text: "  a\nb\tc  ")
        XCTAssertEqual(item.preview, "a b c")
    }

    func testPreviewTruncatesLongString() {
        let long = String(repeating: "x", count: 200)
        let item = ClipboardItem(kind: .text, text: long)
        XCTAssertEqual(item.preview.count, 78) // 77 + ellipsis
        XCTAssertTrue(item.preview.hasSuffix("…"))
    }

    func testFingerprintStability() {
        let a = ClipboardItem(id: UUID(), kind: .text, text: "same", createdAt: Date())
        let b = ClipboardItem(id: UUID(), kind: .text, text: "same", createdAt: Date().addingTimeInterval(60))
        XCTAssertEqual(a.fingerprint, b.fingerprint)
    }

    func testFingerprintDiffersByKind() {
        let a = ClipboardItem(kind: .text, text: "x")
        let b = ClipboardItem(kind: .richText, text: "x")
        XCTAssertNotEqual(a.fingerprint, b.fingerprint)
    }

    func testCodableRoundTrip() throws {
        let original = ClipboardItem(kind: .text, text: "round-trip", sourceBundleID: "com.example", isPinned: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertTrue(decoded.isPinned)
    }

    func testBackwardCompatibleDecodeWithoutIsPinned() throws {
        // v0.1 JSON had no `isPinned` field — must default to false.
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "kind": "text",
          "text": "legacy",
          "createdAt": "2026-05-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let item = try decoder.decode(ClipboardItem.self, from: json)
        XCTAssertEqual(item.text, "legacy")
        XCTAssertFalse(item.isPinned)
    }
}
