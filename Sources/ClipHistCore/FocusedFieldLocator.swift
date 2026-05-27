#if canImport(AppKit)
import AppKit
import ApplicationServices

/// Uses the Accessibility API to locate the screen-coordinate frame of the
/// focused UI element. Critically, this can target a *specific* process — used
/// when the panel anchors near the field of the previously-frontmost app rather
/// than ClipHist itself (which has no useful focused field).
///
/// Requires the user to grant Accessibility permission in System Settings.
public enum FocusedFieldLocator {

    /// Returns the focused element's frame for the given process ID, in Cocoa
    /// screen coordinates (origin at bottom-left). Falls back to the system-wide
    /// focused element if `pid` is nil.
    public static func focusedFieldFrame(pid: pid_t? = nil) -> CGRect? {
        guard AXIsProcessTrusted() else { return nil }

        let appElement: AXUIElement
        if let pid = pid {
            appElement = AXUIElementCreateApplication(pid)
        } else {
            let systemWide = AXUIElementCreateSystemWide()
            guard let app: AXUIElement = copyAttribute(systemWide, kAXFocusedApplicationAttribute) else {
                return nil
            }
            appElement = app
        }

        guard let focused: AXUIElement = copyAttribute(appElement, kAXFocusedUIElementAttribute) else {
            return nil
        }
        return frame(of: focused)
    }

    private static func copyAttribute(_ element: AXUIElement, _ attr: String) -> AXUIElement? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard status == .success, let value = value else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
            AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
            let positionRef = positionRef, let sizeRef = sizeRef,
            CFGetTypeID(positionRef) == AXValueGetTypeID(),
            CFGetTypeID(sizeRef) == AXValueGetTypeID()
        else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

        // AX coordinates have origin at the top-left of the primary display.
        // Flip into Cocoa screen coordinates (origin at the bottom-left).
        guard let screen = NSScreen.screens.first else { return nil }
        let flippedY = screen.frame.height - position.y - size.height
        return CGRect(x: position.x, y: flippedY, width: size.width, height: size.height)
    }
}
#endif
