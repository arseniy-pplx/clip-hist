# Architecture

ClipHist is a small SwiftPM project split into a UI-free **core library** and a thin **AppKit/SwiftUI app target** that owns the menu bar and panel.

```
┌──────────────────────────────────────────────────────────────┐
│  ClipHist (executable)                                       │
│  ┌────────────────────┐    ┌──────────────────────────────┐  │
│  │  AppDelegate       │───▶│  MenuBarController           │  │
│  │  · loads Settings  │    │  · NSStatusItem              │  │
│  │  · wires monitor   │    │  · NSPanel (HistoryPanelView)│  │
│  │  · registers hotkey│    │  · Settings window           │  │
│  └─────────┬──────────┘    └──────────────┬───────────────┘  │
│            │                              │ pick(item)       │
│            ▼                              ▼                  │
│  ┌────────────────────┐    ┌──────────────────────────────┐  │
│  │  ClipboardMonitor  │───▶│  HistoryStore  (core)        │  │
│  │  · polls NSPaste-  │    │  · capped, dedup, paginated  │  │
│  │    board changeCnt │    │  · JSON persistence          │  │
│  └────────────────────┘    └──────────────────────────────┘  │
│                                                              │
│  HotKey (Carbon RegisterEventHotKey)                         │
│  Paster (CGEvent ⌘V synthesis)                               │
│  FocusedFieldLocator (AX API)                                │
└──────────────────────────────────────────────────────────────┘
```

## Targets

- **`ClipHistCore`** — pure-Swift, no AppKit-only deps in headers, fully unit-testable.
  - `ClipboardItem` — codable value type with `fingerprint` for dedup.
  - `HistoryStore` — thread-safe, capacity-bounded LRU-ish store with JSON persistence and `page(index:size:query:)`.
  - `Settings` / `SettingsStore` — `UserDefaults`-backed configuration with validation.
  - `HotKeySpec` — serializable hotkey description with `displayString`.
  - **AppKit-gated** files (`#if canImport(AppKit)`): `ClipboardMonitor`, `Paster`, `HotKey`, `FocusedFieldLocator`. They compile only on macOS and are excluded from any future Linux SwiftPM consumer.

- **`ClipHist`** — executable target.
  - `main.swift` boots `NSApplication` in `.accessory` mode.
  - `AppDelegate` wires the lifecycle.
  - `MenuBarController` owns the status item, dropdown panel, and settings window.
  - `HistoryPanelView`, `SettingsView` — SwiftUI.

## Why polling for the pasteboard

AppKit does not emit a notification when the system pasteboard changes. Every well-known clipboard manager (Pastebot, Paste, Maccy) polls `NSPasteboard.changeCount` at 100–1000 ms. ClipHist polls every 500 ms — adjustable in code if needed.

## Why Carbon for the hotkey

`NSEvent.addGlobalMonitorForEvents` requires Accessibility permission and does not let the app consume the event. `RegisterEventHotKey` is the only API that:

1. Works without Accessibility permission (the OS dispatches the event directly).
2. Consumes the keystroke so it does not also reach the foreground app.

## Why Accessibility for "anchor near input field"

The position of an arbitrary text field belonging to another process can only be obtained via the Accessibility API (`AXUIElementCopyAttributeValue` with `kAXFocusedUIElement` → `kAXPosition`, `kAXSize`). When permission is not granted, `FocusedFieldLocator` returns `nil` and `MenuBarController` falls back to anchoring on the status-item button.

## Persistence

History is serialized to `~/Library/Application Support/ClipHist/history.json` on every mutation. The store is written atomically (`Data.write(options: .atomic)`) so a crash mid-write can never corrupt the file.

## Threading model

`HistoryStore` uses an internal serial `DispatchQueue` and exposes only synchronous, thread-safe entry points. SwiftUI views read the store from the main thread; the polling timer also runs on the main run loop. There is no shared mutable state outside the store.

## Testing

`Tests/ClipHistCoreTests/` covers:

- Insert / dedup / move-to-front / capacity eviction (`HistoryStoreTests`)
- Pagination including out-of-range and partial last page (`PaginationTests`)
- JSON round-trip and capacity-on-load (`PersistenceTests`)
- Settings validation, hotkey display formatting, `UserDefaults` round-trip (`SettingsTests`)
- `ClipboardItem` preview formatting and `Codable` (`ClipboardItemTests`)

The UI layer is deliberately thin and is exercised manually plus via CI build verification — no XCUITests, by design (they're flaky and slow for a menu-bar app).
