#if canImport(AppKit)
import AppKit
import ApplicationServices

/// Uses the Accessibility API to locate the screen-coordinate frame of the
/// currently focused UI element (the input field the user is typing into).
/// Requires the user to grant Accessibility permission in System Settings.
public enum FocusedFieldLocator {
    /// Returns the focused element's frame in Cocoa screen coordinates
    /// (origin at bottom-left), or `nil` if it can't be determined.
    public static func focusedFieldFrame() -> CGRect? {
        guard AXIsProcessTrusted() else { return nil }

        let systemWide = AXUIElementCreateSystemWide()

        guard let appElement: AXUIElement = copyAttribute(systemWide, kAXFocusedApplicationAttribute),
              let focused: AXUIElement = copyAttribute(appElement, kAXFocusedUIElementAttribute)
        else { return nil }

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

        // AX coordinates have origin top-left of the primary display; flip to Cocoa.
        guard let screen = NSScreen.screens.first else { return nil }
        let flippedY = screen.frame.height - position.y - size.height
        return CGRect(x: position.x, y: flippedY, width: size.width, height: size.height)
    }
}
#endif
