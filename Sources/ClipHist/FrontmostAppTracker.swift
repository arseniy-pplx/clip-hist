import AppKit

/// Remembers the PID of the most recently activated application that is not
/// ClipHist itself. Used so that when our hotkey fires (and the panel takes
/// focus), we still know which app's input field to anchor near.
final class FrontmostAppTracker {
    private(set) var lastExternalPID: pid_t?
    private var observer: NSObjectProtocol?
    private let ourBundleID = Bundle.main.bundleIdentifier ?? "dev.arseniy.cliphist"

    init() {
        // Seed with whatever is frontmost right now (if it isn't us).
        if let app = NSWorkspace.shared.frontmostApplication,
           app.bundleIdentifier != ourBundleID
        {
            lastExternalPID = app.processIdentifier
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard
                let self = self,
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                app.bundleIdentifier != self.ourBundleID
            else { return }
            self.lastExternalPID = app.processIdentifier
        }
    }

    deinit {
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
