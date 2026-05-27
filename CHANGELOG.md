# Changelog

All notable changes to this project are documented in this file. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
