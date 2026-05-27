#if canImport(AppKit)
import AppKit
import Carbon.HIToolbox

/// Writes a `ClipboardItem` back to the system pasteboard and synthesizes ⌘V
/// so the front app receives a paste event.
public enum Paster {
    public static func paste(_ item: ClipboardItem, pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        switch item.kind {
        case .text:
            pasteboard.setString(item.text, forType: .string)
        case .richText:
            if let b64 = item.payloadBase64, let data = Data(base64Encoded: b64) {
                pasteboard.setData(data, forType: .rtf)
            }
            pasteboard.setString(item.text, forType: .string)
        case .image:
            if let b64 = item.payloadBase64,
               let data = Data(base64Encoded: b64),
               let img = NSImage(data: data)
            {
                pasteboard.writeObjects([img])
            }
        case .file:
            let urls = item.text.split(separator: "\n").compactMap { URL(fileURLWithPath: String($0)) }
            if !urls.isEmpty {
                pasteboard.writeObjects(urls as [NSURL])
            }
        }
        synthesizeCommandV()
    }

    /// Posts a synthetic ⌘V key-down/key-up pair to the active application.
    private static func synthesizeCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // kVK_ANSI_V
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand
        // Slight delay lets the pasteboard settle before the keystroke is delivered.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }
}
#endif
