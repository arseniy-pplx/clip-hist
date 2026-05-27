import AppKit
import ClipHistCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore()
    private(set) var settings: AppSettings = .default

    private(set) lazy var historyStore: HistoryStore = {
        HistoryStore(
            capacity: settings.maxEntries,
            storageURL: HistoryStore.defaultStorageURL()
        )
    }()

    private lazy var monitor = ClipboardMonitor(store: historyStore)
    private lazy var hotKey = HotKey()
    private let frontmostTracker = FrontmostAppTracker()
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = settingsStore.load()
        historyStore.setCapacity(settings.maxEntries)
        monitor.ignoredBundleIDs = Set(settings.ignoredBundleIDs)
        monitor.start()

        let controller = MenuBarController(
            historyStore: historyStore,
            settingsProvider: { [weak self] in self?.settings ?? .default },
            onUpdateSettings: { [weak self] new in self?.apply(settings: new) },
            externalAppPIDProvider: { [weak self] in self?.frontmostTracker.lastExternalPID }
        )
        self.menuBar = controller

        registerHotKey()
        applyLaunchAtLogin(enabled: settings.launchAtLogin)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if settings.clearOnQuit {
            historyStore.clear()
        }
        monitor.stop()
        hotKey.unregister()
    }

    // MARK: - Settings application

    func apply(settings new: AppSettings) {
        let validated = new.validated()
        settings = validated
        settingsStore.save(validated)
        historyStore.setCapacity(validated.maxEntries)
        monitor.ignoredBundleIDs = Set(validated.ignoredBundleIDs)
        registerHotKey()
        applyLaunchAtLogin(enabled: validated.launchAtLogin)
    }

    private func registerHotKey() {
        hotKey.unregister()
        hotKey.register(spec: settings.hotKey) { [weak self] in
            self?.menuBar?.togglePanel()
        }
    }

    private func applyLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                NSLog("ClipHist: launch-at-login update failed: \(error.localizedDescription)")
            }
        }
    }
}
