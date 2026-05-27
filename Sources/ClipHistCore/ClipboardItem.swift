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

    public init(
        id: UUID = UUID(),
        kind: Kind,
        text: String,
        payloadBase64: String? = nil,
        createdAt: Date = Date(),
        sourceBundleID: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.payloadBase64 = payloadBase64
        self.createdAt = createdAt
        self.sourceBundleID = sourceBundleID
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
