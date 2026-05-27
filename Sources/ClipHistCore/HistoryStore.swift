import Foundation

/// Thread-safe (via internal queue) clipboard history with capped capacity,
/// dedup-on-insert, JSON persistence, and pagination.
public final class HistoryStore: @unchecked Sendable {
    public struct Page: Equatable, Sendable {
        public let items: [ClipboardItem]
        public let pageIndex: Int
        public let pageSize: Int
        public let totalItems: Int

        public init(items: [ClipboardItem], pageIndex: Int, pageSize: Int, totalItems: Int) {
            self.items = items
            self.pageIndex = pageIndex
            self.pageSize = pageSize
            self.totalItems = totalItems
        }

        public var totalPages: Int {
            guard pageSize > 0 else { return 0 }
            return Int((Double(totalItems) / Double(pageSize)).rounded(.up))
        }
    }

    private let queue = DispatchQueue(label: "clip-hist.store", qos: .userInitiated)
    private var items: [ClipboardItem] = []
    private let storageURL: URL?
    public private(set) var capacity: Int

    public init(capacity: Int = 100, storageURL: URL? = nil) {
        self.capacity = max(1, capacity)
        self.storageURL = storageURL
        if let url = storageURL, let loaded = Self.load(from: url) {
            self.items = Array(loaded.prefix(self.capacity))
        }
    }

    // MARK: - Mutations

    /// Inserts a new item at the head. If the new item's fingerprint matches the
    /// current head, it is treated as a no-op (consecutive duplicates collapse).
    /// Returns true if the store was modified.
    @discardableResult
    public func insert(_ item: ClipboardItem) -> Bool {
        queue.sync {
            if let head = items.first, head.fingerprint == item.fingerprint {
                return false
            }
            // Move-to-front if the same fingerprint exists elsewhere.
            if let existingIndex = items.firstIndex(where: { $0.fingerprint == item.fingerprint }) {
                items.remove(at: existingIndex)
            }
            items.insert(item, at: 0)
            if items.count > capacity {
                items.removeLast(items.count - capacity)
            }
            persistLocked()
            return true
        }
    }

    public func remove(id: UUID) {
        queue.sync {
            items.removeAll { $0.id == id }
            persistLocked()
        }
    }

    public func clear() {
        queue.sync {
            items.removeAll()
            persistLocked()
        }
    }

    public func setCapacity(_ newCapacity: Int) {
        queue.sync {
            capacity = max(1, newCapacity)
            if items.count > capacity {
                items.removeLast(items.count - capacity)
            }
            persistLocked()
        }
    }

    // MARK: - Reads

    public var count: Int { queue.sync { items.count } }

    public func all() -> [ClipboardItem] { queue.sync { items } }

    /// Returns a page of items, optionally filtered by a case-insensitive
    /// substring search over the `text` field.
    public func page(index: Int, size: Int, query: String? = nil) -> Page {
        queue.sync {
            let pageSize = max(1, size)
            let filtered: [ClipboardItem]
            if let q = query?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
                filtered = items.filter { $0.text.range(of: q, options: .caseInsensitive) != nil }
            } else {
                filtered = items
            }
            let clampedIndex = max(0, index)
            let start = clampedIndex * pageSize
            guard start < filtered.count else {
                return Page(items: [], pageIndex: clampedIndex, pageSize: pageSize, totalItems: filtered.count)
            }
            let end = min(start + pageSize, filtered.count)
            return Page(
                items: Array(filtered[start..<end]),
                pageIndex: clampedIndex,
                pageSize: pageSize,
                totalItems: filtered.count
            )
        }
    }

    // MARK: - Persistence

    private func persistLocked() {
        guard let url = storageURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
            // Persistence failures are non-fatal; the in-memory store still works.
        }
    }

    private static func load(from url: URL) -> [ClipboardItem]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([ClipboardItem].self, from: data)
    }

    /// Default on-disk location for the JSON store.
    public static func defaultStorageURL(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("ClipHist/history.json")
    }
}
