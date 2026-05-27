import SwiftUI
import ClipHistCore

struct SettingsView: View {
    let initial: Settings
    let onSave: (Settings) -> Void

    @State private var maxEntries: Double
    @State private var pageSize: Double
    @State private var launchAtLogin: Bool
    @State private var clearOnQuit: Bool
    @State private var anchorNearFocusedField: Bool
    @State private var ignoredBundles: String
    @State private var hotKey: HotKeySpec
    @State private var recording = false

    init(initial: Settings, onSave: @escaping (Settings) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _maxEntries = State(initialValue: Double(initial.maxEntries))
        _pageSize = State(initialValue: Double(initial.pageSize))
        _launchAtLogin = State(initialValue: initial.launchAtLogin)
        _clearOnQuit = State(initialValue: initial.clearOnQuit)
        _anchorNearFocusedField = State(initialValue: initial.anchorNearFocusedField)
        _ignoredBundles = State(initialValue: initial.ignoredBundleIDs.joined(separator: "\n"))
        _hotKey = State(initialValue: initial.hotKey)
    }

    var body: some View {
        Form {
            Section("History") {
                HStack {
                    Text("Max entries: \(Int(maxEntries))").frame(width: 140, alignment: .leading)
                    Slider(value: $maxEntries, in: 10...1000, step: 10)
                }
                HStack {
                    Text("Page size: \(Int(pageSize))").frame(width: 140, alignment: .leading)
                    Slider(value: $pageSize, in: 5...50, step: 1)
                }
                Toggle("Clear history on quit", isOn: $clearOnQuit)
            }

            Section("Shortcut") {
                HStack {
                    Text("Open panel:").frame(width: 140, alignment: .leading)
                    Button(action: recordShortcut) {
                        Text(recording ? "Press a key…" : hotKey.displayString)
                            .frame(minWidth: 120)
                    }
                    Button("Reset") { hotKey = .default }
                }
            }

            Section("Behavior") {
                Toggle("Anchor panel near focused input field", isOn: $anchorNearFocusedField)
                Toggle("Launch at login", isOn: $launchAtLogin)
            }

            Section("Ignored apps (one bundle ID per line)") {
                TextEditor(text: $ignoredBundles)
                    .frame(height: 80)
                    .font(.system(.body, design: .monospaced))
                    .border(Color.secondary.opacity(0.3))
                Text("Example: com.1password.1password7, com.apple.keychainaccess")
                    .font(.caption).foregroundColor(.secondary)
            }

            HStack {
                Spacer()
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 440)
        .onExitCommand { save() }
        .background(KeyCaptureView(active: $recording) { spec in
            hotKey = spec
            recording = false
        })
    }

    private func recordShortcut() { recording = true }

    private func save() {
        let bundles = ignoredBundles
            .split(whereSeparator: { $0.isNewline || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let new = Settings(
            maxEntries: Int(maxEntries),
            pageSize: Int(pageSize),
            hotKey: hotKey,
            launchAtLogin: launchAtLogin,
            ignoredBundleIDs: bundles,
            clearOnQuit: clearOnQuit,
            anchorNearFocusedField: anchorNearFocusedField
        )
        onSave(new)
    }
}

/// Captures the next key combination pressed while `active` is true and
/// reports it as a `HotKeySpec`. Lives inside an `NSViewRepresentable` so it
/// can install a local key-down monitor scoped to this window.
private struct KeyCaptureView: NSViewRepresentable {
    @Binding var active: Bool
    let onCapture: (HotKeySpec) -> Void

    func makeNSView(context: Context) -> NSView { Holder(active: $active, onCapture: onCapture) }
    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? Holder)?.refresh()
    }

    final class Holder: NSView {
        @Binding var active: Bool
        let onCapture: (HotKeySpec) -> Void
        private var monitor: Any?

        init(active: Binding<Bool>, onCapture: @escaping (HotKeySpec) -> Void) {
            self._active = active
            self.onCapture = onCapture
            super.init(frame: .zero)
            refresh()
        }
        required init?(coder: NSCoder) { fatalError() }
        deinit { if let m = monitor { NSEvent.removeMonitor(m) } }

        func refresh() {
            if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
            guard active else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.active else { return event }
                let cocoaFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                var carbon: UInt32 = 0
                if cocoaFlags.contains(.command) { carbon |= 0x0100 }
                if cocoaFlags.contains(.shift)   { carbon |= 0x0200 }
                if cocoaFlags.contains(.option)  { carbon |= 0x0800 }
                if cocoaFlags.contains(.control) { carbon |= 0x1000 }
                guard carbon != 0 else { return event } // require a modifier
                self.onCapture(HotKeySpec(modifiers: carbon, keyCode: UInt32(event.keyCode)))
                return nil
            }
        }
    }
}
