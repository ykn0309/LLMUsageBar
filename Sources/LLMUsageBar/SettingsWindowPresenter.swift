import SwiftUI

@MainActor
final class SettingsWindowPresenter {
    static let shared = SettingsWindowPresenter()

    private var window: NSWindow?

    private init() {}

    func show(store: UsageStore) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let controller = NSHostingController(
            rootView: SettingsView()
                .environmentObject(store)
                .frame(minWidth: 740, idealWidth: 840, minHeight: 520, idealHeight: 600)
        )
        let window = NSWindow(contentViewController: controller)
        window.title = "LLMUsageBar 设置"
        window.setContentSize(NSSize(width: 840, height: 600))
        window.minSize = NSSize(width: 740, height: 520)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.window = window
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
