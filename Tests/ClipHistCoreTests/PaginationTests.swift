import XCTest
@testable import ClipHistCore

final class PaginationTests: XCTestCase {

    private func seed(_ store: HistoryStore, count: Int) {
        for i in 0..<count {
            store.insert(.init(kind: .text, text: "entry-\(i)"))
        }
    }

    func testFirstPage() {
        let store = HistoryStore(capacity: 100)
        seed(store, count: 25)
        let page = store.page(index: 0, size: 10)
        XCTAssertEqual(page.items.count, 10)
        XCTAssertEqual(page.items.first?.text, "entry-24") // newest first
        XCTAssertEqual(page.totalItems, 25)
        XCTAssertEqual(page.totalPages, 3)
    }

    func testLastPagePartial() {
        let store = HistoryStore(capacity: 100)
        seed(store, count: 25)
        let page = store.page(index: 2, size: 10)
        XCTAssertEqual(page.items.count, 5)
        XCTAssertEqual(page.pageIndex, 2)
    }

    func testOutOfRangePage() {
        let store = HistoryStore(capacity: 100)
        seed(store, count: 25)
        let page = store.page(index: 99, size: 10)
        XCTAssertTrue(page.items.isEmpty)
        XCTAssertEqual(page.totalItems, 25)
    }

    func testSearchFilter() {
        let store = HistoryStore(capacity: 100)
        store.insert(.init(kind: .text, text: "alpha"))
        store.insert(.init(kind: .text, text: "beta gamma"))
        store.insert(.init(kind: .text, text: "GAMMA delta"))
        let page = store.page(index: 0, size: 10, query: "gamma")
        XCTAssertEqual(page.totalItems, 2)
        XCTAssertEqual(Set(page.items.map(\.text)), ["beta gamma", "GAMMA delta"])
    }

    func testEmptyQueryReturnsAll() {
        let store = HistoryStore(capacity: 100)
        seed(store, count: 5)
        let page = store.page(index: 0, size: 10, query: "   ")
        XCTAssertEqual(page.totalItems, 5)
    }
}
