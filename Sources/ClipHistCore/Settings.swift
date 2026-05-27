import Foundation

/// User-configurable settings persisted via `UserDefaults`.
public struct AppSettings: Codable, Equatable, Sendable {
    public var maxEntries: Int
    public var pageSize: Int
    public var hotKey: HotKeySpec
    public var launchAtLogin: Bool
    public var ignoredBundleIDs: [String]
    public var clearOnQuit: Bool
    public var anchorNearFocusedField: Bool

    public init(
        maxEntries: Int = 100,
        pageSize: Int = 10,
        hotKey: HotKeySpec = .default,
        launchAtLogin: Bool = false,
        ignoredBundleIDs: [String] = [],
        clearOnQuit: Bool = false,
        anchorNearFocusedField: Bool = true
    ) {
        self.maxEntries = maxEntries
        self.pageSize = pageSize
        self.hotKey = hotKey
        self.launchAtLogin = launchAtLogin
        self.ignoredBundleIDs = ignoredBundleIDs
        self.clearOnQuit = clearOnQuit
        self.anchorNearFocusedField = anchorNearFocusedField
    }

    public static let `default` = AppSettings()

    /// Clamp values to safe ranges before applying.
    public func validated() -> AppSettings {
        var copy = self
        copy.maxEntries = min(max(copy.maxEntries, 10), 1000)
        copy.pageSize = min(max(copy.pageSize, 5), 100)
        return copy
    }
}

/// Serializable description of a global hotkey.
public struct HotKeySpec: Codable, Equatable, Sendable {
    /// Bitmask of `Carbon` modifier flags (cmdKey | optionKey | controlKey | shiftKey).
    public var modifiers: UInt32
    /// Carbon virtual key code (kVK_ANSI_V == 9).
    public var keyCode: UInt32

    public init(modifiers: UInt32, keyCode: UInt32) {
        self.modifiers = modifiers
        self.keyCode = keyCode
    }

    /// Default: ⌃⌘V  (control + command + V)
    /// cmdKey = 0x0100, controlKey = 0x1000, kVK_ANSI_V = 9
    public static let `default` = HotKeySpec(modifiers: 0x0100 | 0x1000, keyCode: 9)

    public var displayString: String {
        var parts: [String] = []
        if modifiers & 0x1000 != 0 { parts.append("⌃") }
        if modifiers & 0x0800 != 0 { parts.append("⌥") }
        if modifiers & 0x0200 != 0 { parts.append("⇧") }
        if modifiers & 0x0100 != 0 { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    private static func keyName(for code: UInt32) -> String {
        // Subset of the Carbon kVK_* table covering common keys.
        let map: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
            38: "J", 40: "K", 45: "N", 46: "M",
            49: "Space", 36: "Return", 48: "Tab", 53: "Esc",
        ]
        return map[code] ?? "Key\(code)"
    }
}

/// `UserDefaults`-backed settings repository.
public final class SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "ClipHist.Settings.v1") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> AppSettings {
        guard
            let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return .default
        }
        return decoded.validated()
    }

    public func save(_ settings: AppSettings) {
        let validated = settings.validated()
        guard let data = try? JSONEncoder().encode(validated) else { return }
        defaults.set(data, forKey: key)
    }
}
