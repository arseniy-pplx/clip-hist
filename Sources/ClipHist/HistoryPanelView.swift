import SwiftUI
import ClipHistCore

struct HistoryPanelView: View {
    let store: HistoryStore
    let settings: AppSettings
    let onPick: (ClipboardItem) -> Void
    let onCopy: (ClipboardItem) -> Void
    let onTogglePin: (ClipboardItem) -> Void
    let onDelete: (ClipboardItem) -> Void
    let onClose: () -> Void
    let onOpenSettings: () -> Void
    let onClear: () -> Void

    @State private var query: String = ""
    @State private var pageIndex: Int = 0
    @State private var page: HistoryStore.Page = .init(items: [], pageIndex: 0, pageSize: 10, totalItems: 0)
    @State private var selection: UUID?
    @FocusState private var searchFocused: Bool
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
        .frame(width: 400, height: 480)
        .background(KeyHandler(
            onArrowUp: moveSelection(by: -1),
            onArrowDown: moveSelection(by: 1),
            onReturn: { activateSelection() },
            onEscape: { onClose() },
            onDelete: { deleteSelection() },
            onCommandDigit: { digit in pasteByDigit(digit) },
            onCommandP: { togglePinSelection() }
        ))
        .onAppear {
            reload()
            searchFocused = true
        }
        .onReceive(refresh) { _ in reload() }
        .onChange(of: query) { _ in pageIndex = 0; reload() }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Search clipboard…", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if page.items.isEmpty {
                        Text(query.isEmpty ? "No clipboard history yet." : "No matches.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    }
                    ForEach(Array(page.items.enumerated()), id: \.element.id) { index, item in
                        Row(
                            item: item,
                            hotkeyDigit: index < 9 ? index + 1 : nil,
                            isSelected: selection == item.id,
                            onActivate: { activate(item) },
                            onCopy: { onCopy(item); onClose() },
                            onTogglePin: { onTogglePin(item); reload() },
                            onDelete: { onDelete(item); reload() },
                            onHover: { hovering in
                                if hovering { selection = item.id }
                            }
                        )
                        .id(item.id)
                    }
                }
            }
            .onChange(of: selection) { newID in
                if let id = newID {
                    withAnimation(.linear(duration: 0.1)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button(action: prevPage) { Image(systemName: "chevron.left") }
                .disabled(pageIndex == 0)
                .buttonStyle(.borderless)
            Text("Page \(page.pageIndex + 1) / \(max(page.totalPages, 1))")
                .font(.caption).foregroundColor(.secondary)
            Button(action: nextPage) { Image(systemName: "chevron.right") }
                .disabled(pageIndex + 1 >= page.totalPages)
                .buttonStyle(.borderless)
            Spacer()
            Text("\(page.totalItems) items").font(.caption).foregroundColor(.secondary)
            Button(action: onOpenSettings) { Image(systemName: "gearshape") }
                .buttonStyle(.borderless)
                .help("Settings")
            Button(action: onClear) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help("Clear history")
        }
    }

    // MARK: - State

    private func reload() {
        page = store.page(index: pageIndex, size: settings.pageSize, query: query)
        // Clamp page if it became out-of-bounds after a deletion/eviction.
        if pageIndex > 0, page.items.isEmpty, page.totalItems > 0 {
            pageIndex = max(0, page.totalPages - 1)
            page = store.page(index: pageIndex, size: settings.pageSize, query: query)
        }
        // Maintain a sensible default selection.
        if let sel = selection, !page.items.contains(where: { $0.id == sel }) {
            selection = page.items.first?.id
        } else if selection == nil {
            selection = page.items.first?.id
        }
    }

    private func prevPage() {
        guard pageIndex > 0 else { return }
        pageIndex -= 1
        reload()
        selection = page.items.first?.id
    }

    private func nextPage() {
        guard pageIndex + 1 < page.totalPages else { return }
        pageIndex += 1
        reload()
        selection = page.items.first?.id
    }

    // MARK: - Activation

    /// Single click on a row. Behavior depends on `pasteOnClick` setting.
    private func activate(_ item: ClipboardItem) {
        if settings.pasteOnClick {
            onPick(item)
        } else {
            selection = item.id
            onCopy(item)
        }
    }

    /// Enter key always pastes (regardless of paste-on-click).
    private func activateSelection() {
        guard let id = selection, let item = page.items.first(where: { $0.id == id }) else { return }
        onPick(item)
    }

    private func deleteSelection() {
        guard let id = selection, let item = page.items.first(where: { $0.id == id }) else { return }
        onDelete(item)
        reload()
    }

    private func togglePinSelection() {
        guard let id = selection, let item = page.items.first(where: { $0.id == id }) else { return }
        onTogglePin(item)
        reload()
    }

    private func pasteByDigit(_ digit: Int) {
        let idx = digit - 1
        guard idx >= 0, idx < page.items.count else { return }
        onPick(page.items[idx])
    }

    private func moveSelection(by delta: Int) -> () -> Void {
        return {
            guard !page.items.isEmpty else { return }
            let currentIndex = selection.flatMap { id in page.items.firstIndex(where: { $0.id == id }) } ?? -1
            var next = currentIndex + delta
            if next < 0 {
                // Up at the top → previous page (last item)
                if pageIndex > 0 {
                    pageIndex -= 1
                    reload()
                    selection = page.items.last?.id
                }
                return
            }
            if next >= page.items.count {
                // Down at the bottom → next page (first item)
                if pageIndex + 1 < page.totalPages {
                    pageIndex += 1
                    reload()
                    selection = page.items.first?.id
                }
                return
            }
            next = min(max(next, 0), page.items.count - 1)
            selection = page.items[next].id
        }
    }
}

private struct Row: View {
    let item: ClipboardItem
    let hotkeyDigit: Int?
    let isSelected: Bool
    let onActivate: () -> Void
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onHover: (Bool) -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            thumbnail
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    }
                    Text(item.preview).lineLimit(2)
                }
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
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                if isHovered || isSelected {
                    Button(action: onTogglePin) {
                        Image(systemName: item.isPinned ? "pin.slash" : "pin")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help(item.isPinned ? "Unpin" : "Pin")
                }
                if let digit = hotkeyDigit {
                    Text("⌘\(digit)").font(.caption2.monospaced()).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(rowBackground)
        .cornerRadius(5)
        .contentShape(Rectangle())
        .onTapGesture { onActivate() }
        .onHover { hovering in
            isHovered = hovering
            onHover(hovering)
        }
        .contextMenu {
            Button("Paste") { onActivate() }
            Button("Copy") { onCopy() }
            Button(item.isPinned ? "Unpin" : "Pin") { onTogglePin() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    @ViewBuilder private var rowBackground: some View {
        if isSelected {
            Color.accentColor.opacity(0.25)
        } else if isHovered {
            Color.primary.opacity(0.08)
        } else {
            Color.clear
        }
    }

    @ViewBuilder private var thumbnail: some View {
        switch item.kind {
        case .image:
            if let b64 = item.payloadBase64,
               let data = Data(base64Encoded: b64),
               let nsImage = NSImage(data: data)
            {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 28, height: 28)
                    .clipped()
                    .cornerRadius(3)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary.opacity(0.3), lineWidth: 0.5))
            } else {
                Image(systemName: "photo")
            }
        case .text:
            Image(systemName: "doc.plaintext").foregroundColor(.secondary)
        case .richText:
            Image(systemName: "doc.richtext").foregroundColor(.secondary)
        case .file:
            Image(systemName: "doc").foregroundColor(.secondary)
        }
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}

/// Invisible NSView that translates key presses into closures. Lives in the
/// SwiftUI tree as a background and forwards key events to the panel.
private struct KeyHandler: NSViewRepresentable {
    let onArrowUp: () -> Void
    let onArrowDown: () -> Void
    let onReturn: () -> Void
    let onEscape: () -> Void
    let onDelete: () -> Void
    let onCommandDigit: (Int) -> Void
    let onCommandP: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = Holder()
        view.handler = self
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? Holder)?.handler = self
    }

    final class Holder: NSView {
        var handler: KeyHandler?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.dispatch(event) ?? event
            }
        }

        deinit { if let m = monitor { NSEvent.removeMonitor(m) } }

        private func dispatch(_ event: NSEvent) -> NSEvent? {
            guard let h = handler, window?.isKeyWindow == true else { return event }
            let cmd = event.modifierFlags.contains(.command)

            // ⌘1…⌘9 quick-paste — works even when the search field has focus.
            if cmd, let chars = event.charactersIgnoringModifiers,
               chars.count == 1, let digit = Int(chars), digit >= 1, digit <= 9
            {
                h.onCommandDigit(digit)
                return nil
            }
            // ⌘P — toggle pin on the selected row.
            if cmd, event.charactersIgnoringModifiers?.lowercased() == "p" {
                h.onCommandP()
                return nil
            }

            switch event.keyCode {
            case 126: h.onArrowUp(); return nil      // up arrow
            case 125: h.onArrowDown(); return nil    // down arrow
            case 36, 76: h.onReturn(); return nil    // return / numpad enter
            case 53: h.onEscape(); return nil        // escape
            case 51, 117:                            // delete / forward-delete
                // Only consume the delete key when the search field is empty;
                // otherwise let it edit the text.
                if let editor = window?.firstResponder as? NSText, !editor.string.isEmpty {
                    return event
                }
                h.onDelete()
                return nil
            default: return event
            }
        }
    }
}
