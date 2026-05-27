#if canImport(AppKit)
import AppKit
import Carbon.HIToolbox

/// Writes a `ClipboardItem` back to the system pasteboard and synthesizes ⌘V
/// so the front app receives a paste event.
public enum Paster {

    /// Writes the item to the pasteboard. If `targetPID` is provided, that app
    /// is reactivated first and the synthetic ⌘V is delivered after a short
    /// delay so the destination app's text field has time to regain focus.
    public static func paste(
        _ item: ClipboardItem,
        targetPID: pid_t? = nil,
        pasteboard: NSPasteboard = .general
    ) {
        writeToPasteboard(item, pasteboard: pasteboard)
        let activated = activate(pid: targetPID)
        // Slightly longer delay when we had to reactivate another app.
        synthesizeCommandV(delay: activated ? 0.12 : 0.05)
    }

    /// Just copy the item to the pasteboard — used when "paste on click" is
    /// disabled and the user only wants to refresh the current clipboard.
    public static func copyToClipboard(_ item: ClipboardItem, pasteboard: NSPasteboard = .general) {
        writeToPasteboard(item, pasteboard: pasteboard)
    }

    private static func writeToPasteboard(_ item: ClipboardItem, pasteboard: NSPasteboard) {
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
    }

    @discardableResult
    private static func activate(pid: pid_t?) -> Bool {
        guard let pid = pid,
              let app = NSRunningApplication(processIdentifier: pid)
        else { return false }
        return app.activate(options: [])
    }

    /// Posts a synthetic ⌘V key-down/key-up pair to the active application.
    private static func synthesizeCommandV(delay: TimeInterval) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // kVK_ANSI_V
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand
        // Slight delay lets the pasteboard settle and the target app regain focus.
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }
}
#endif
