import Foundation

enum ConfigStore {
    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".llm-usage-bar", isDirectory: true)
    }

    static var configURL: URL {
        directory.appendingPathComponent("config.json")
    }

    static func loadOrCreate() throws -> AppConfig {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: configURL.path) {
            try save(AppConfig.sample)
        }

        let data = try Data(contentsOf: configURL)
        var config = try JSONDecoder().decode(AppConfig.self, from: data)
        migrate(&config)
        return config
    }

    static func save(_ config: AppConfig) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: .atomic)
    }

    static func revealCommand() -> String {
        "open \(directory.path)"
    }

    private static func migrate(_ config: inout AppConfig) {
        if let index = config.providers.firstIndex(where: { $0.id == "openai-codex" }) {
            config.providers[index].name = "OpenAI Codex"
            config.providers[index].kind = .codexUsage
            config.providers[index].apiKey = nil
            config.providers[index].url = nil
            config.providers[index].method = nil
            config.providers[index].headers = nil
            config.providers[index].body = nil
            config.providers[index].valuePaths = nil
            config.providers[index].currency = nil
            config.providers[index].monthlyBudget = nil
        } else {
            config.providers.append(ProviderConfig(
                id: "openai-codex",
                name: "OpenAI Codex",
                kind: .codexUsage,
                enabled: false,
                apiKey: nil,
                url: nil,
                method: nil,
                headers: nil,
                body: nil,
                valuePaths: nil,
                currency: nil,
                monthlyBudget: nil,
                command: nil
            ))
        }

        for index in config.providers.indices {
            if config.providers[index].id == "minimax",
               config.providers[index].kind == .httpJSON,
               config.providers[index].url == "https://example.com/balance" {
                config.providers[index].kind = .minimaxBalance
                config.providers[index].url = nil
                config.providers[index].method = nil
                config.providers[index].headers = nil
                config.providers[index].valuePaths = nil
            }

            if config.providers[index].id == "aliyun-bailian",
               config.providers[index].kind == .command,
               config.providers[index].command == "aliyun bssopenapi QueryAccountBalance" {
                config.providers[index].command = "aliyun bssopenapi QueryAccountBalance --RegionId cn-hangzhou"
            }

            if config.providers[index].id == "aliyun-bailian",
               config.providers[index].kind == .command {
                config.providers[index].valuePaths = nil
            }
        }

        let fixedOrder = ["deepseek", "minimax", "aliyun-bailian", "openai-codex"]
        let fixedIDs = Set(fixedOrder)
        config.providers.removeAll { !fixedIDs.contains($0.id) }

        for provider in AppConfig.sample.providers where !config.providers.contains(where: { $0.id == provider.id }) {
            config.providers.append(provider)
        }
        for index in config.providers.indices {
            switch config.providers[index].id {
            case "deepseek":
                config.providers[index].kind = .deepseekBalance
            case "minimax":
                config.providers[index].kind = .minimaxBalance
            case "aliyun-bailian":
                config.providers[index].kind = .command
                config.providers[index].command = nil
            case "openai-codex":
                config.providers[index].kind = .codexUsage
            default:
                break
            }
        }

        let rank = Dictionary(uniqueKeysWithValues: fixedOrder.enumerated().map { ($0.element, $0.offset) })
        config.providers.sort { (rank[$0.id] ?? .max) < (rank[$1.id] ?? .max) }
    }
}
