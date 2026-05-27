# Changelog

All notable changes to this project are documented in this file. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.2.0] — 2026-05-27

### Added
- **Pinned items** — pin/unpin via right-click, hover button, or `⌘P`. Pinned items sort to the top and are exempt from capacity eviction.
- **Image preview thumbnails** inline in history rows.
- **Row hover highlight** and selection highlight.
- **Full keyboard navigation**: `↑`/`↓` (with cross-page auto-advance), `⏎` to paste, `⌘1`–`⌘9` quick-paste, `⌘P` pin, `⌫` delete, `Esc` close.
- **Paste-on-click vs select-on-click** setting. When off, clicking a row only copies it to the system clipboard; `⏎` always pastes.
- **App icon** — generated `AppIcon.icns` (clipboard glyph on blue squircle), embedded in the bundle.
- **DMG installer with installer UI** — `create-dmg` layout with custom background, drag-to-Applications hint, volume icon.
- **Frontmost-app tracking** so the panel anchors near the previously-active app's focused field (instead of ClipHist's own window) and returns focus before pasting.
- Backward-compatible decoding for v0.1 history and settings JSON.

### Fixed
- **Settings window layout** — labels no longer clip on the left and the "Reset" button no longer clips on the right; sliders constrained, alignment normalized.
- **Hotkey-opened panel** now correctly anchors near the focused input field of the previously-active app (was falling back to the status item because ClipHist had just stolen focus).

## [0.1.0] — 2026-05-27

### Added
- Menu-bar app with status-item icon and right-click menu.
- Clipboard monitor (polls `NSPasteboard.changeCount` every 0.5s).
- History store with capacity cap (10–1000), dedup, move-to-front, JSON persistence.
- Pagination + case-insensitive substring search.
- Global hotkey (default `⌃⌘V`) via Carbon `RegisterEventHotKey`, rebindable in settings.
- Dropdown panel anchored near the focused input field via Accessibility API.
- Paste-on-click with synthesized `⌘V` keystroke.
- Settings: max entries, page size, hotkey, launch at login (`SMAppService`), ignored bundle IDs, clear-on-quit, anchor-to-field toggle.
- Text, rich text, image, and file URL clipboard types.
- Privacy filter for `org.nspasteboard.ConcealedType` and configurable ignored apps.
- XCTest suite covering core history, pagination, persistence, settings, and item formatting.
- CI workflow: build + test + coverage + `.app` artifact upload on every push/PR.
- Release workflow: universal binary `.app.zip` and `.dmg` attached to GitHub Release on `v*` tags.
- README, architecture doc, contributing guide.
