# Contributing

## Branching

- All changes go through pull request review — never push to `main`.
- Open PRs in **draft** state until CI is green and self-review is complete.
- One PR = one logical change. Keep diffs small.

## Local workflow

```bash
# Run tests
swift test

# Build a local dev .app (arm64 only, fast)
bash scripts/build-app.sh --arch arm64
open build/ClipHist.app
```

## Code style

- Swift 5.9. Use the standard formatter (`swift-format` or `swiftformat` — either is fine, CI does not gate on style yet).
- No external runtime dependencies. The whole point of this app is "small and self-contained".
- Keep `ClipHistCore` pure-Swift where possible. AppKit-only files must be wrapped in `#if canImport(AppKit)`.
- New public API in `ClipHistCore` must come with a test.

## Commit messages

Follow Conventional Commits where reasonable:

```
feat(history): add fuzzy search
fix(monitor): ignore concealed pasteboard types
docs(readme): clarify Accessibility permission
ci: bump macos runner to 14
```

## Releasing

1. Bump `CFBundleShortVersionString` in `Resources/Info.plist`.
2. Update `CHANGELOG.md`.
3. Tag: `git tag v0.2.0 && git push --tags`.
4. The `Release` workflow builds the universal `.app`, packages a `.dmg`, and attaches both to the GitHub Release.
