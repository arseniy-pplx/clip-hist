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
            self.items = loaded
            evictLocked()
        }
    }

    // MARK: - Mutations

    /// Inserts a new item at the head. If the new item's fingerprint matches the
    /// current head, it is treated as a no-op (consecutive duplicates collapse).
    /// Returns true if the store was modified.
    @discardableResult
    public func insert(_ item: ClipboardItem) -> Bool {
        queue.sync {
            // Preserve pin state across re-inserts: if an existing item with the
            // same fingerprint is pinned, keep it pinned and just refresh recency.
            var newItem = item
            if let existingIndex = items.firstIndex(where: { $0.fingerprint == item.fingerprint }) {
                let existing = items[existingIndex]
                if existing.isPinned { newItem.isPinned = true }
                // If the head (in sorted order) already matches, treat as no-op.
                if sortedLocked().first?.fingerprint == item.fingerprint, !newItem.isPinned {
                    return false
                }
                items.remove(at: existingIndex)
            }
            items.append(newItem)
            evictLocked()
            persistLocked()
            return true
        }
    }

    /// Toggle pin state for an item. Returns the new state, or nil if not found.
    @discardableResult
    public func togglePin(id: UUID) -> Bool? {
        queue.sync {
            guard let idx = items.firstIndex(where: { $0.id == id }) else { return nil }
            items[idx].isPinned.toggle()
            let newState = items[idx].isPinned
            evictLocked()
            persistLocked()
            return newState
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
            evictLocked()
            persistLocked()
        }
    }

    /// Eviction rule: pinned items are never evicted; only unpinned items count
    /// against `capacity`. Oldest unpinned items are dropped first.
    private func evictLocked() {
        let unpinned = items.filter { !$0.isPinned }
        guard unpinned.count > capacity else { return }
        let excess = unpinned.count - capacity
        // Mark the `excess` oldest unpinned items for removal.
        let toRemoveIDs = Set(
            unpinned.sorted(by: { $0.createdAt < $1.createdAt })
                .prefix(excess)
                .map(\.id)
        )
        items.removeAll { toRemoveIDs.contains($0.id) }
    }

    // MARK: - Reads

    public var count: Int { queue.sync { items.count } }

    public func all() -> [ClipboardItem] { queue.sync { sortedLocked() } }

    /// Pinned items first (newest pin first), then unpinned (newest first).
    private func sortedLocked() -> [ClipboardItem] {
        items.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned && !b.isPinned }
            return a.createdAt > b.createdAt
        }
    }

    /// Returns a page of items, optionally filtered by a case-insensitive
    /// substring search over the `text` field.
    public func page(index: Int, size: Int, query: String? = nil) -> Page {
        queue.sync {
            let pageSize = max(1, size)
            let sorted = sortedLocked()
            let filtered: [ClipboardItem]
            if let q = query?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
                filtered = sorted.filter { $0.text.range(of: q, options: .caseInsensitive) != nil }
            } else {
                filtered = sorted
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
