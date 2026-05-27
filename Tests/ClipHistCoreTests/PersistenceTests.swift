import XCTest
@testable import ClipHistCore

final class PersistenceTests: XCTestCase {

    private func tempURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cliphist-tests-\(UUID().uuidString)", isDirectory: true)
        return dir.appendingPathComponent("history.json")
    }

    func testRoundTrip() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let s1 = HistoryStore(capacity: 10, storageURL: url)
        s1.insert(.init(kind: .text, text: "one"))
        s1.insert(.init(kind: .text, text: "two"))
        s1.insert(.init(kind: .text, text: "three"))

        let s2 = HistoryStore(capacity: 10, storageURL: url)
        XCTAssertEqual(s2.all().map(\.text), ["three", "two", "one"])
    }

    func testCapacityAppliedOnLoad() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let s1 = HistoryStore(capacity: 50, storageURL: url)
        for i in 0..<20 { s1.insert(.init(kind: .text, text: "i\(i)")) }

        let s2 = HistoryStore(capacity: 5, storageURL: url)
        XCTAssertEqual(s2.count, 5)
        XCTAssertEqual(s2.all().first?.text, "i19")
    }

    func testMissingFileGivesEmptyStore() {
        let url = tempURL()
        let store = HistoryStore(capacity: 10, storageURL: url)
        XCTAssertEqual(store.count, 0)
    }
}
