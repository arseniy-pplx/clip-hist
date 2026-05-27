import SwiftUI
import ClipHistCore

struct SettingsView: View {
    let initial: AppSettings
    let onSave: (AppSettings) -> Void

    @State private var maxEntries: Double
    @State private var pageSize: Double
    @State private var launchAtLogin: Bool
    @State private var clearOnQuit: Bool
    @State private var anchorNearFocusedField: Bool
    @State private var pasteOnClick: Bool
    @State private var ignoredBundles: String
    @State private var hotKey: HotKeySpec
    @State private var recording = false

    init(initial: AppSettings, onSave: @escaping (AppSettings) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _maxEntries = State(initialValue: Double(initial.maxEntries))
        _pageSize = State(initialValue: Double(initial.pageSize))
        _launchAtLogin = State(initialValue: initial.launchAtLogin)
        _clearOnQuit = State(initialValue: initial.clearOnQuit)
        _anchorNearFocusedField = State(initialValue: initial.anchorNearFocusedField)
        _pasteOnClick = State(initialValue: initial.pasteOnClick)
        _ignoredBundles = State(initialValue: initial.ignoredBundleIDs.joined(separator: "\n"))
        _hotKey = State(initialValue: initial.hotKey)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("History") {
                    sliderRow(
                        label: "Max entries",
                        value: $maxEntries,
                        range: 10...1000,
                        step: 10,
                        valueText: "\(Int(maxEntries))"
                    )
                    sliderRow(
                        label: "Page size",
                        value: $pageSize,
                        range: 5...50,
                        step: 1,
                        valueText: "\(Int(pageSize))"
                    )
                    Toggle("Clear history on quit", isOn: $clearOnQuit)
                }

                section("Shortcut") {
                    HStack(spacing: 12) {
                        Text("Open panel")
                            .frame(width: labelWidth, alignment: .leading)
                        Button(action: { recording = true }) {
                            Text(recording ? "Press a key…" : hotKey.displayString)
                                .frame(minWidth: 120)
                        }
                        Button("Reset") { hotKey = .default }
                        Spacer(minLength: 0)
                    }
                }

                section("Behavior") {
                    Toggle("Anchor panel near focused input field", isOn: $anchorNearFocusedField)
                    Toggle("Paste immediately on row click", isOn: $pasteOnClick)
                        .help("If off, clicking a row only copies it to the clipboard. Press ⏎ to paste.")
                    Toggle("Launch at login", isOn: $launchAtLogin)
                }

                section("Ignored apps") {
                    Text("One bundle ID per line. Clipboard changes from these apps are skipped.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $ignoredBundles)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 90)
                        .padding(4)
                        .background(Color.secondary.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3), lineWidth: 0.5))
                    Text("Example: com.1password.1password7")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Spacer()
                    Button("Cancel") { NSApp.keyWindow?.close() }
                    Button("Save") { save() }
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 540, height: 540)
        .background(KeyCaptureView(active: $recording) { spec in
            hotKey = spec
            recording = false
        })
    }

    // MARK: - Helpers

    private let labelWidth: CGFloat = 110

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            content()
        }
    }

    @ViewBuilder
    private func sliderRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        valueText: String
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(width: labelWidth, alignment: .leading)
            Slider(value: value, in: range, step: step)
                .frame(maxWidth: 280)
            Text(valueText)
                .frame(width: 50, alignment: .trailing)
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
    }

    private func save() {
        let bundles = ignoredBundles
            .split(whereSeparator: { $0.isNewline || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let new = AppSettings(
            maxEntries: Int(maxEntries),
            pageSize: Int(pageSize),
            hotKey: hotKey,
            launchAtLogin: launchAtLogin,
            ignoredBundleIDs: bundles,
            clearOnQuit: clearOnQuit,
            anchorNearFocusedField: anchorNearFocusedField,
            pasteOnClick: pasteOnClick
        )
        onSave(new)
    }
}

/// Captures the next key combination pressed while `active` is true and
/// reports it as a `HotKeySpec`.
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
