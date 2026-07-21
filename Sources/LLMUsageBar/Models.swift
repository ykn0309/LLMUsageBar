import Foundation

enum ProviderKind: String, Codable, CaseIterable, Identifiable {
    case deepseekBalance
    case minimaxBalance
    case codexUsage
    case openAIMonthlyCost
    case httpJSON
    case command

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deepseekBalance: "DeepSeek 余额"
        case .minimaxBalance: "MiniMax 配额"
        case .codexUsage: "OpenAI Codex 配额"
        case .openAIMonthlyCost: "OpenAI API 本月成本"
        case .httpJSON: "HTTP JSON"
        case .command: "命令"
        }
    }
}

struct AppConfig: Codable {
    var refreshSeconds: TimeInterval
    var providers: [ProviderConfig]

    static let sample = AppConfig(
        refreshSeconds: 300,
        providers: [
            ProviderConfig(
                id: "deepseek",
                name: "DeepSeek",
                kind: .deepseekBalance,
                enabled: true,
                apiKey: nil,
                url: nil,
                method: nil,
                headers: nil,
                body: nil,
                valuePaths: [],
                currency: nil,
                monthlyBudget: nil,
                command: nil
            ),
            ProviderConfig(
                id: "minimax",
                name: "MiniMax",
                kind: .minimaxBalance,
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
            ),
            ProviderConfig(
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
            ),
            ProviderConfig(
                id: "aliyun-bailian",
                name: "阿里云百炼",
                kind: .command,
                enabled: false,
                apiKey: nil,
                url: nil,
                method: nil,
                headers: nil,
                body: nil,
                valuePaths: nil,
                currency: "CNY",
                monthlyBudget: nil,
                command: "aliyun bssopenapi QueryAccountBalance --RegionId cn-hangzhou"
            )
        ]
    )
}

struct ProviderConfig: Codable, Identifiable {
    var id: String
    var name: String
    var kind: ProviderKind
    var enabled: Bool
    var apiKey: String?
    var url: String?
    var method: String?
    var headers: [String: String]?
    var body: String?
    var valuePaths: [String]?
    var currency: String?
    var monthlyBudget: Double?
    var command: String?
}

struct UsageItem: Identifiable, Equatable {
    var id: String
    var name: String
    var kind: ProviderKind
    var primaryText: String
    var secondaryText: String
    var status: UsageStatus
    var updatedAt: Date?
    var metrics: [UsageMetric] = []
}

struct UsageMetric: Identifiable, Equatable {
    var id: String
    var label: String
    var percent: Double
    var detail: String
}

enum UsageStatus: Equatable {
    case idle
    case loading
    case ok
    case warning
    case failed(String)

    var symbolName: String {
        switch self {
        case .idle: "circle"
        case .loading: "arrow.triangle.2.circlepath"
        case .ok: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failed: "xmark.circle.fill"
        }
    }
}
