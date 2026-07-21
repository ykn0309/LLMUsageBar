import SwiftUI

@main
struct LLMUsageBarApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            UsagePanelView()
                .environmentObject(store)
                .frame(width: 390)
                .task {
                    await store.start()
                }
        } label: {
            Label(store.menuTitle, systemImage: store.menuIcon)
        }
        .menuBarExtraStyle(.window)
    }
}
