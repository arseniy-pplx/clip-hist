import Foundation

/// A single entry in the clipboard history.
public struct ClipboardItem: Codable, Identifiable, Equatable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case text
        case richText
        case image
        case file
    }

    public let id: UUID
    public let kind: Kind
    /// Plain-text representation (used for search/preview). For images this is a placeholder.
    public let text: String
    /// Optional rich payload base64-encoded (RTF bytes, image PNG bytes, file URL string).
    public let payloadBase64: String?
    public let createdAt: Date
    /// Source application bundle identifier, if known.
    public let sourceBundleID: String?
    /// Pinned items sort to the top and are not subject to capacity eviction.
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        kind: Kind,
        text: String,
        payloadBase64: String? = nil,
        createdAt: Date = Date(),
        sourceBundleID: String? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.payloadBase64 = payloadBase64
        self.createdAt = createdAt
        self.sourceBundleID = sourceBundleID
        self.isPinned = isPinned
    }

    /// Decoding with backward-compatible default for `isPinned` (added in v0.2).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decode(Kind.self, forKey: .kind)
        text = try c.decode(String.self, forKey: .text)
        payloadBase64 = try c.decodeIfPresent(String.self, forKey: .payloadBase64)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        sourceBundleID = try c.decodeIfPresent(String.self, forKey: .sourceBundleID)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, text, payloadBase64, createdAt, sourceBundleID, isPinned
    }

    /// Stable fingerprint used to deduplicate consecutive identical copies.
    public var fingerprint: String {
        "\(kind.rawValue):\(text.hashValue):\(payloadBase64?.hashValue ?? 0)"
    }

    /// Short single-line preview, suitable for menu rows.
    public var preview: String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespaces)
        if collapsed.count <= 80 { return collapsed }
        return String(collapsed.prefix(77)) + "…"
    }
}
