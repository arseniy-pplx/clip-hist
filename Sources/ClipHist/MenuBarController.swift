import AppKit
import SwiftUI
import ClipHistCore

/// Owns the status-bar item and the floating dropdown panel.
final class MenuBarController: NSObject, NSWindowDelegate {
    private let historyStore: HistoryStore
    private let settingsProvider: () -> Settings
    private let onUpdateSettings: (Settings) -> Void

    private let statusItem: NSStatusItem
    private var panel: NSPanel?
    private var settingsWindow: NSWindow?

    init(
        historyStore: HistoryStore,
        settingsProvider: @escaping () -> Settings,
        onUpdateSettings: @escaping (Settings) -> Void
    ) {
        self.historyStore = historyStore
        self.settingsProvider = settingsProvider
        self.onUpdateSettings = onUpdateSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        let image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "Clipboard History"
        )
        image?.isTemplate = true
        button.image = image
        button.target = self
        button.action = #selector(handleStatusClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func handleStatusClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            togglePanel()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show History", action: #selector(togglePanel), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
            .target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
            .target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit ClipHist", action: #selector(quit), keyEquivalent: "q")
            .target = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // detach so left-clicks remain custom
    }

    // MARK: - Panel

    @objc func togglePanel() {
        if let panel = panel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        showPanel()
    }

    private func showPanel() {
        let panel = panel ?? makePanel()
        self.panel = panel

        let origin = panelOrigin()
        panel.setFrameTopLeftPoint(origin)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makePanel() -> NSPanel {
        let view = HistoryPanelView(
            store: historyStore,
            settings: settingsProvider(),
            onPick: { [weak self] item in
                self?.pick(item: item)
            },
            onOpenSettings: { [weak self] in
                self?.showSettings()
            },
            onClear: { [weak self] in
                self?.historyStore.clear()
            }
        )
        let hosting = NSHostingController(rootView: view)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 460),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.delegate = self
        return panel
    }

    /// Computes a top-left origin for the dropdown that is anchored near the
    /// focused text field when possible, falling back to the status item.
    private func panelOrigin() -> NSPoint {
        let settings = settingsProvider()
        let panelSize = panel?.frame.size ?? CGSize(width: 380, height: 460)

        if settings.anchorNearFocusedField,
           let frame = FocusedFieldLocator.focusedFieldFrame()
        {
            // Place the panel just below the field, left-aligned with it.
            var origin = NSPoint(x: frame.minX, y: frame.minY - 6)
            if let screen = NSScreen.main {
                origin.x = max(screen.frame.minX + 8, min(origin.x, screen.frame.maxX - panelSize.width - 8))
                if origin.y - panelSize.height < screen.frame.minY {
                    // Not enough room below — show above the field instead.
                    origin.y = frame.maxY + panelSize.height + 6
                }
            }
            return origin
        }
        if let button = statusItem.button,
           let window = button.window
        {
            let buttonFrame = button.convert(button.bounds, to: nil)
            let screenFrame = window.convertToScreen(buttonFrame)
            return NSPoint(x: screenFrame.minX, y: screenFrame.minY - 4)
        }
        return NSPoint(x: 100, y: 100)
    }

    private func pick(item: ClipboardItem) {
        panel?.orderOut(nil)
        Paster.paste(item)
    }

    // MARK: - Window delegate

    func windowDidResignKey(_ notification: Notification) {
        panel?.orderOut(nil)
    }

    // MARK: - Settings window

    @objc func showSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = SettingsView(
            initial: settingsProvider(),
            onSave: { [weak self] new in
                self?.onUpdateSettings(new)
            }
        )
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 460),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClipHist Settings"
        window.contentViewController = hosting
        window.center()
        window.isReleasedWhenClosed = false
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func clearHistory() {
        historyStore.clear()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
