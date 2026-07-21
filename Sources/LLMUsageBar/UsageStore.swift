import Foundation
import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var config: AppConfig = .sample
    @Published private(set) var items: [UsageItem] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastRefresh: Date?

    private var refreshTask: Task<Void, Never>?

    var menuTitle: String {
        if isRefreshing {
            return "LLM"
        }
        let failures = items.filter {
            if case .failed = $0.status { return true }
            return false
        }.count
        if failures > 0 {
            return "\(failures) 异常"
        }
        return items.first?.primaryText ?? "LLM"
    }

    var menuIcon: String {
        if items.contains(where: {
            if case .failed = $0.status { return true }
            return false
        }) {
            return "exclamationmark.circle"
        }
        return "chart.bar.xaxis"
    }

    func start() async {
        guard refreshTask == nil else { return }
        loadConfig()
        await refresh()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                let seconds = await MainActor.run { self?.config.refreshSeconds ?? 300 }
                try? await Task.sleep(nanoseconds: UInt64(max(seconds, 30) * 1_000_000_000))
                await self?.refresh()
            }
        }
    }

    func loadConfig() {
        do {
            config = try ConfigStore.loadOrCreate()
            resetItems()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveConfig(_ nextConfig: AppConfig) throws {
        try ConfigStore.save(nextConfig)
        config = nextConfig
        resetItems()
        errorMessage = nil
    }

    func refresh() async {
        let providers = config.providers.filter(\.enabled).map(UsageProvider.init(config:))
        guard !providers.isEmpty else {
            items = []
            return
        }

        isRefreshing = true
        let loadingIDs = Set(providers.map(\.config.id))
        items = items.map { item in
            guard loadingIDs.contains(item.id) else { return item }
            var next = item
            next.status = .loading
            return next
        }

        let results = await withTaskGroup(of: UsageItem.self) { group in
            for provider in providers {
                group.addTask {
                    await provider.fetch()
                }
            }

            var values: [UsageItem] = []
            for await item in group {
                values.append(item)
            }
            return values.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        }

        items = results
        lastRefresh = Date()
        isRefreshing = false
    }

    func openConfigFolder() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [ConfigStore.directory.path]
        try? process.run()
    }

    func reloadAndRefresh() {
        loadConfig()
        Task {
            await refresh()
        }
    }

    private func resetItems() {
        let enabled = config.providers.filter(\.enabled)
        items = enabled.map {
            UsageItem(
                id: $0.id,
                name: $0.name,
                kind: $0.kind,
                primaryText: "等待刷新",
                secondaryText: $0.kind.displayName,
                status: .idle,
                updatedAt: nil
            )
        }
    }
}
