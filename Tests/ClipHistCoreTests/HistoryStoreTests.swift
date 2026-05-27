import XCTest
@testable import ClipHistCore

final class HistoryStoreTests: XCTestCase {

    func testInsertAndCount() {
        let store = HistoryStore(capacity: 5)
        store.insert(.init(kind: .text, text: "hello"))
        store.insert(.init(kind: .text, text: "world"))
        XCTAssertEqual(store.count, 2)
        XCTAssertEqual(store.all().first?.text, "world")
    }

    func testConsecutiveDuplicateCollapses() {
        let store = HistoryStore(capacity: 10)
        let inserted1 = store.insert(.init(kind: .text, text: "x"))
        let inserted2 = store.insert(.init(kind: .text, text: "x"))
        XCTAssertTrue(inserted1)
        XCTAssertFalse(inserted2)
        XCTAssertEqual(store.count, 1)
    }

    func testMoveToFrontOnReinsert() {
        let store = HistoryStore(capacity: 10)
        store.insert(.init(kind: .text, text: "a"))
        store.insert(.init(kind: .text, text: "b"))
        store.insert(.init(kind: .text, text: "c"))
        // Re-copying "a" should move it to the front and not duplicate.
        store.insert(.init(kind: .text, text: "a"))
        let texts = store.all().map(\.text)
        XCTAssertEqual(texts, ["a", "c", "b"])
    }

    func testCapacityEviction() {
        let store = HistoryStore(capacity: 3)
        for i in 0..<10 {
            store.insert(.init(kind: .text, text: "i\(i)"))
        }
        XCTAssertEqual(store.count, 3)
        XCTAssertEqual(store.all().map(\.text), ["i9", "i8", "i7"])
    }

    func testShrinkCapacityEvictsOldest() {
        let store = HistoryStore(capacity: 10)
        for i in 0..<8 { store.insert(.init(kind: .text, text: "i\(i)")) }
        store.setCapacity(3)
        XCTAssertEqual(store.count, 3)
        XCTAssertEqual(store.all().map(\.text), ["i7", "i6", "i5"])
    }

    func testRemoveById() {
        let store = HistoryStore(capacity: 10)
        let item = ClipboardItem(kind: .text, text: "drop me")
        store.insert(item)
        store.insert(.init(kind: .text, text: "keep"))
        store.remove(id: item.id)
        XCTAssertEqual(store.all().map(\.text), ["keep"])
    }

    func testClear() {
        let store = HistoryStore(capacity: 5)
        store.insert(.init(kind: .text, text: "a"))
        store.insert(.init(kind: .text, text: "b"))
        store.clear()
        XCTAssertEqual(store.count, 0)
    }
}
