import XCTest
@testable import ClipHistCore

final class PinningTests: XCTestCase {

    func testPinnedItemsSortToTop() {
        let store = HistoryStore(capacity: 10)
        store.insert(.init(kind: .text, text: "a"))
        store.insert(.init(kind: .text, text: "b"))
        store.insert(.init(kind: .text, text: "c"))
        // Order is [c, b, a] (newest first). Pin "a".
        let aID = store.all().last!.id
        let newState = store.togglePin(id: aID)
        XCTAssertEqual(newState, true)
        let order = store.all().map(\.text)
        XCTAssertEqual(order, ["a", "c", "b"])
    }

    func testPinnedItemsExemptFromCapacity() {
        let store = HistoryStore(capacity: 3)
        // Insert and pin "keepme" first.
        store.insert(.init(kind: .text, text: "keepme"))
        let pinID = store.all().first!.id
        store.togglePin(id: pinID)

        // Now push 5 more unpinned entries.
        for i in 0..<5 {
            store.insert(.init(kind: .text, text: "u\(i)"))
        }

        let texts = store.all().map(\.text)
        // 1 pinned + 3 unpinned (the newest three) = 4 total
        XCTAssertEqual(store.count, 4)
        XCTAssertEqual(texts.first, "keepme")
        XCTAssertEqual(Array(texts.dropFirst()), ["u4", "u3", "u2"])
    }

    func testUnpinReintroducesEvictionPressure() {
        let store = HistoryStore(capacity: 2)
        store.insert(.init(kind: .text, text: "old"))
        let oldID = store.all().first!.id
        store.togglePin(id: oldID)

        store.insert(.init(kind: .text, text: "a"))
        store.insert(.init(kind: .text, text: "b"))
        store.insert(.init(kind: .text, text: "c"))
        // Pinned "old" + 2 newest unpinned
        XCTAssertEqual(store.all().map(\.text), ["old", "c", "b"])

        // Unpin "old" — it becomes the oldest unpinned and gets evicted.
        store.togglePin(id: oldID)
        XCTAssertEqual(store.count, 2)
        XCTAssertEqual(store.all().map(\.text), ["c", "b"])
    }

    func testRepasteOfPinnedItemStaysPinned() {
        let store = HistoryStore(capacity: 10)
        store.insert(.init(kind: .text, text: "hello"))
        let id = store.all().first!.id
        store.togglePin(id: id)
        XCTAssertTrue(store.all().first!.isPinned)

        // Copying "hello" again should keep it pinned.
        store.insert(.init(kind: .text, text: "world"))
        store.insert(.init(kind: .text, text: "hello"))
        let first = store.all().first!
        XCTAssertEqual(first.text, "hello")
        XCTAssertTrue(first.isPinned)
    }

    func testTogglePinReturnsNilForUnknownID() {
        let store = HistoryStore(capacity: 5)
        XCTAssertNil(store.togglePin(id: UUID()))
    }
}
