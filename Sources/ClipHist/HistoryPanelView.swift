import SwiftUI
import ClipHistCore

struct HistoryPanelView: View {
    let store: HistoryStore
    let settings: AppSettings
    let onPick: (ClipboardItem) -> Void
    let onOpenSettings: () -> Void
    let onClear: () -> Void

    @State private var query: String = ""
    @State private var pageIndex: Int = 0
    @State private var page: HistoryStore.Page = .init(items: [], pageIndex: 0, pageSize: 10, totalItems: 0)
    private let refresh = Timer.publish(every: 0.7, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 8) {
            searchBar
            Divider()
            list
            Divider()
            footer
        }
        .padding(10)
        .frame(width: 380, height: 460)
        .onAppear(perform: reload)
        .onReceive(refresh) { _ in reload() }
        .onChange(of: query) { _ in pageIndex = 0; reload() }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Search clipboard…", text: $query)
                .textFieldStyle(.plain)
            if !query.isEmpty {
                Button(action: { query = "" }) { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundColor(.secondary)
            }
        }
        .padding(6)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if page.items.isEmpty {
                    Text(query.isEmpty ? "No clipboard history yet." : "No matches.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                }
                ForEach(Array(page.items.enumerated()), id: \.element.id) { index, item in
                    Row(item: item, hotkeyDigit: index < 9 ? index + 1 : nil)
                        .contentShape(Rectangle())
                        .onTapGesture { onPick(item) }
                        .contextMenu {
                            Button("Paste") { onPick(item) }
                            Button("Copy") {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.setString(item.text, forType: .string)
                            }
                            Button("Delete", role: .destructive) {
                                store.remove(id: item.id)
                                reload()
                            }
                        }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button(action: prevPage) { Image(systemName: "chevron.left") }
                .disabled(pageIndex == 0)
                .keyboardShortcut(.leftArrow, modifiers: [])
            Text("Page \(page.pageIndex + 1) / \(max(page.totalPages, 1))")
                .font(.caption).foregroundColor(.secondary)
            Button(action: nextPage) { Image(systemName: "chevron.right") }
                .disabled(pageIndex + 1 >= page.totalPages)
                .keyboardShortcut(.rightArrow, modifiers: [])
            Spacer()
            Text("\(page.totalItems) items").font(.caption).foregroundColor(.secondary)
            Button(action: onOpenSettings) { Image(systemName: "gearshape") }
                .buttonStyle(.plain)
            Button(action: onClear) { Image(systemName: "trash") }
                .buttonStyle(.plain)
        }
    }

    private func reload() {
        page = store.page(index: pageIndex, size: settings.pageSize, query: query)
        // Clamp page if it became out-of-bounds after a deletion/eviction.
        if pageIndex > 0, page.items.isEmpty, page.totalItems > 0 {
            pageIndex = max(0, page.totalPages - 1)
            page = store.page(index: pageIndex, size: settings.pageSize, query: query)
        }
    }

    private func prevPage() {
        guard pageIndex > 0 else { return }
        pageIndex -= 1
        reload()
    }

    private func nextPage() {
        guard pageIndex + 1 < page.totalPages else { return }
        pageIndex += 1
        reload()
    }
}

private struct Row: View {
    let item: ClipboardItem
    let hotkeyDigit: Int?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            icon
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview).lineLimit(2)
                HStack(spacing: 6) {
                    Text(item.kind.rawValue).font(.caption2)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15)).cornerRadius(3)
                    if let bundle = item.sourceBundleID {
                        Text(bundle).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text(relative(item.createdAt)).font(.caption2).foregroundColor(.secondary)
                }
            }
            if let digit = hotkeyDigit {
                Text("⌘\(digit)").font(.caption2.monospaced()).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(Color.clear)
        .cornerRadius(4)
    }

    @ViewBuilder private var icon: some View {
        switch item.kind {
        case .text: Image(systemName: "doc.plaintext")
        case .richText: Image(systemName: "doc.richtext")
        case .image: Image(systemName: "photo")
        case .file: Image(systemName: "doc")
        }
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}
