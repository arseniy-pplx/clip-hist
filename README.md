# ClipHist

[![CI](https://github.com/arseniy-pplx/clip-hist/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/arseniy-pplx/clip-hist/actions/workflows/ci.yml)
[![CodeQL](https://github.com/arseniy-pplx/clip-hist/actions/workflows/codeql.yml/badge.svg?branch=main)](https://github.com/arseniy-pplx/clip-hist/actions/workflows/codeql.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B-blue)](https://www.apple.com/macos)

A lightweight macOS clipboard history manager. Lives in the menu bar, opens as a dropdown near the input field you're typing into, paginates through your history, and pastes back with a single click or keystroke.

## Features

- **Menu-bar app** — no Dock icon, minimal footprint
- **Configurable history size** — 10 to 1000 entries, capped on disk
- **Pagination + search** — page through results, instant case-insensitive substring search
- **Smart anchoring** — anchors the dropdown next to the focused text field of the previously-active app (Accessibility API)
- **Global hotkey** — rebindable (default `⌃⌘V`) via Carbon `RegisterEventHotKey`
- **Pinned items** — pin any entry to keep it at the top, exempt from capacity eviction
- **Image previews** — thumbnails inline in the history list
- **Hover + selection highlight** with full keyboard navigation
- **Paste on click *or* select on click** — configurable, with `⏎` always pasting
- **Click-to-paste** — writes the entry back to the pasteboard, returns focus to the destination app, and synthesizes `⌘V`
- **Text, rich text, images, and file URLs**
- **Privacy-aware** — ignores `org.nspasteboard.ConcealedType` (password managers) and a user-configurable ignored-bundle-ID list
- **Persistence** — JSON store at `~/Library/Application Support/ClipHist/history.json`
- **Launch at login** via `SMAppService`
- **Clear-on-quit** opt-in
- **Universal binary** — arm64 + x86_64
- **Polished DMG installer** — drag-to-Applications layout with custom background and volume icon

## Requirements

- macOS 13 Ventura or later
- Xcode 15 / Swift 5.9+ to build from source

## Install

### From a release

1. Download `ClipHist.dmg` or `ClipHist.app.zip` from the latest [release](../../releases).
2. Drag `ClipHist.app` into `/Applications`.
3. Launch once. macOS will prompt for **Accessibility** permission — required for:
   - Detecting the focused input field's position (anchoring the dropdown).
   - Synthesizing the `⌘V` keystroke on paste.
4. Grant it in **System Settings → Privacy & Security → Accessibility**.

The binary is ad-hoc signed by CI. On first launch you may need to right-click → Open to bypass Gatekeeper, or run `xattr -d com.apple.quarantine /Applications/ClipHist.app`.

### From source

```bash
git clone git@github.com:arseniy-pplx/clip-hist.git
cd clip-hist
swift test            # run the test suite
bash scripts/build-app.sh --arch universal
open build/ClipHist.app
```

## Usage

| Action | Shortcut |
|---|---|
| Open history dropdown | `⌃⌘V` (rebindable) |
| Move selection up / down | `↑` / `↓` (auto-paginates at edges) |
| Paste selected entry | `⏎` |
| Click row → paste / select | controlled by **Paste immediately on row click** setting |
| Quick-paste row 1–9 | `⌘1` … `⌘9` |
| Pin / unpin selected row | `⌘P` (or pin icon on hover) |
| Delete selected entry | `⌫` (when search is empty) |
| Close panel | `Esc` |
| Search | type in the search field |
| Open settings | menu-bar icon → right-click → Settings |

## Settings

Available from the status-item menu → **Settings…**

- **Max entries** — 10 to 1000
- **Page size** — 5 to 50
- **Open shortcut** — record any modifier + key combination
- **Anchor near focused field** — toggle smart positioning
- **Paste immediately on row click** — on: click pastes; off: click only refreshes the clipboard, `⏎` pastes
- **Launch at login** — registers the app via `SMAppService`
- **Ignored bundle IDs** — one per line; e.g. `com.1password.1password7`
- **Clear on quit** — empty the store when the app terminates

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Development

- Test suite: `swift test`
- Build dev app: `bash scripts/build-app.sh --arch arm64`
- Package DMG: `bash scripts/package-dmg.sh`

CI runs on every push and PR (`macos-14`, Xcode 15.4) and uploads a built `.app` artifact. Tagging `v*` cuts a release with both `.app.zip` and `.dmg` attached.

## License

MIT — see [LICENSE](LICENSE).
