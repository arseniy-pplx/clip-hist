#if canImport(AppKit)
import AppKit
import Carbon.HIToolbox

/// Wraps a `Carbon` `RegisterEventHotKey` registration. The Carbon hotkey API is
/// the only sanctioned way to receive a global keystroke without Accessibility
/// permission on modern macOS.
public final class HotKey {
    public typealias Handler = () -> Void

    private var ref: EventHotKeyRef?
    private var handler: Handler?
    private static var nextID: UInt32 = 1
    private static var registry: [UInt32: HotKey] = [:]
    private static var dispatcherInstalled = false

    public init() {}

    deinit { unregister() }

    @discardableResult
    public func register(spec: HotKeySpec, handler: @escaping Handler) -> Bool {
        unregister()
        Self.installDispatcherIfNeeded()
        self.handler = handler

        let id = Self.nextID
        Self.nextID &+= 1
        var hotKeyID = EventHotKeyID(signature: OSType(0x434C4950) /* 'CLIP' */, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            spec.keyCode,
            spec.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref = ref else { return false }
        self.ref = ref
        Self.registry[id] = self
        return true
    }

    public func unregister() {
        if let ref = ref {
            UnregisterEventHotKey(ref)
            self.ref = nil
        }
        if let id = Self.registry.first(where: { $0.value === self })?.key {
            Self.registry.removeValue(forKey: id)
        }
    }

    private static func installDispatcherIfNeeded() {
        guard !dispatcherInstalled else { return }
        dispatcherInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, _) -> OSStatus in
            guard let event = event else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            HotKey.registry[hotKeyID.id]?.handler?()
            return noErr
        }, 1, &spec, nil, nil)
    }
}
#endif
