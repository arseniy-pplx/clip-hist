import XCTest
@testable import ClipHistCore

final class SettingsTests: XCTestCase {

    func testValidationClampsValues() {
        let s = Settings(maxEntries: 5, pageSize: 1).validated()
        XCTAssertEqual(s.maxEntries, 10)
        XCTAssertEqual(s.pageSize, 5)

        let big = Settings(maxEntries: 10_000, pageSize: 10_000).validated()
        XCTAssertEqual(big.maxEntries, 1000)
        XCTAssertEqual(big.pageSize, 100)
    }

    func testHotKeyDisplayDefault() {
        // ⌃⌘V
        XCTAssertEqual(HotKeySpec.default.displayString, "⌃⌘V")
    }

    func testHotKeyDisplayCustom() {
        // ⇧⌥⌘Space (cmd 0x100 | option 0x800 | shift 0x200 = 0xB00)
        let spec = HotKeySpec(modifiers: 0x0100 | 0x0800 | 0x0200, keyCode: 49)
        XCTAssertEqual(spec.displayString, "⌥⇧⌘Space")
    }

    func testSettingsStoreRoundTrip() {
        let suite = "cliphist-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = SettingsStore(defaults: defaults, key: "k")
        var s = Settings.default
        s.maxEntries = 250
        s.pageSize = 25
        s.ignoredBundleIDs = ["com.example.app"]
        s.clearOnQuit = true
        store.save(s)

        let loaded = store.load()
        XCTAssertEqual(loaded.maxEntries, 250)
        XCTAssertEqual(loaded.pageSize, 25)
        XCTAssertEqual(loaded.ignoredBundleIDs, ["com.example.app"])
        XCTAssertTrue(loaded.clearOnQuit)
    }

    func testDefaultsWhenMissing() {
        let suite = "cliphist-empty-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults, key: "absent")
        XCTAssertEqual(store.load(), .default)
    }
}
