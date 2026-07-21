import Foundation

enum ProviderError: LocalizedError {
    case missingHeaderToken(String)
    case missingURL
    case invalidURL(String)
    case invalidResponse
    case httpStatus(Int, String)
    case noBalance
    case noBalanceDetails(String)
    case allAttemptsFailed([String])
    case codexCLINotFound
    case codexProtocol(String)
    case aliyunCLINotFound
    case commandFailed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .missingHeaderToken(let name): "缺少环境变量：\(name)"
        case .missingURL: "缺少 URL"
        case .invalidURL(let url): "URL 无效：\(url)"
        case .invalidResponse: "响应无效"
        case .httpStatus(let code, let body): "HTTP \(code): \(body)"
        case .noBalance: "没有从响应中解析到余额/用量"
        case .noBalanceDetails(let details): "没有从响应中解析到余额/用量：\(details)"
        case .allAttemptsFailed(let errors): errors.joined(separator: "；")
        case .codexCLINotFound: "未找到 Codex CLI，请先安装并运行 codex login"
        case .codexProtocol(let message): "Codex App Server：\(message)"
        case .aliyunCLINotFound: "未找到阿里云 CLI，请先安装并完成 aliyun configure"
        case .commandFailed(let code, let output): "命令失败 \(code): \(output)"
        }
    }
}

struct UsageProvider {
    let config: ProviderConfig

    func fetch() async -> UsageItem {
        do {
            let result: UsageItem
            switch config.kind {
            case .deepseekBalance:
                result = try await fetchDeepSeek()
            case .minimaxBalance:
                result = try await fetchMiniMax()
            case .codexUsage:
                result = try fetchCodexUsage()
            case .openAIMonthlyCost:
                result = try await fetchOpenAIMonthlyCost()
            case .httpJSON:
                result = try await fetchHTTPJSON()
            case .command:
                result = try fetchAliyunBalance()
            }
            return result
        } catch {
            return UsageItem(
                id: config.id,
                name: config.name,
                kind: config.kind,
                primaryText: "获取失败",
                secondaryText: error.localizedDescription,
                status: .failed(error.localizedDescription),
                updatedAt: Date()
            )
        }
    }

    private func fetchDeepSeek() async throws -> UsageItem {
        let request = try makeRequest(
            urlString: "https://api.deepseek.com/user/balance",
            method: "GET",
            headers: authHeaders(),
            body: nil
        )
        let object = try await requestJSON(request)
        let balances = DynamicJSON.values(in: object, path: "balance_infos.*")

        var parts: [String] = []
        for balance in balances {
            let currency = DynamicJSON.firstString(in: balance, paths: ["currency"]) ?? ""
            if let total = DynamicJSON.firstString(in: balance, paths: ["total_balance"]) {
                parts.append("\(currency) \(formatDecimal(total))")
            }
        }

        guard !parts.isEmpty else {
            throw ProviderError.noBalance
        }

        let available = (DynamicJSON.values(in: object, path: "is_available").first as? Bool) ?? true
        return UsageItem(
            id: config.id,
            name: config.name,
            kind: config.kind,
            primaryText: parts.joined(separator: " / "),
            secondaryText: available ? "余额可用" : "余额不足",
            status: available ? .ok : .warning,
            updatedAt: Date()
        )
    }

    private func fetchOpenAIMonthlyCost() async throws -> UsageItem {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let startOfMonth = calendar.date(from: components) else {
            throw ProviderError.invalidResponse
        }

        let start = Int(startOfMonth.timeIntervalSince1970)
        let url = "https://api.openai.com/v1/organization/costs?start_time=\(start)&bucket_width=1d&limit=31"
        let request = try makeRequest(
            urlString: url,
            method: "GET",
            headers: authHeaders(),
            body: nil
        )
        let object = try await requestJSON(request)
        let costs = DynamicJSON.numericValues(in: object, path: "data.*.results.*.amount.value")
        let total = costs.reduce(0, +)
        let currency = config.currency ?? DynamicJSON.firstString(in: object, paths: ["data.0.results.0.amount.currency"])?.uppercased() ?? "USD"

        let primary: String
        let secondary: String
        let status: UsageStatus
        if let budget = config.monthlyBudget {
            let remaining = budget - total
            primary = "\(currency) \(formatNumber(remaining))"
            secondary = "本月已用 \(currency) \(formatNumber(total)) / 预算 \(formatNumber(budget))"
            status = remaining >= 0 ? .ok : .warning
        } else {
            primary = "\(currency) \(formatNumber(total))"
            secondary = "本月组织 API 成本"
            status = .ok
        }

        return UsageItem(
            id: config.id,
            name: config.name,
            kind: config.kind,
            primaryText: primary,
            secondaryText: secondary,
            status: status,
            updatedAt: Date()
        )
    }

    private func fetchMiniMax() async throws -> UsageItem {
        var errors: [String] = []
        var object: Any?

        for url in minimaxQuotaURLs() {
            do {
                let request = try makeRequest(
                    urlString: url,
                    method: "GET",
                    headers: authHeaders(),
                    body: nil
                )
                object = try await requestJSON(request)
                break
            } catch {
                errors.append("\(url): \(error.localizedDescription)")
            }
        }

        guard let object else {
            throw ProviderError.allAttemptsFailed(errors)
        }

        let remains = DynamicJSON.values(in: object, path: "model_remains.*")
        guard !remains.isEmpty else {
            let details = DynamicJSON.firstString(in: object, paths: [
                "base_resp.status_msg",
                "base_resp.message",
                "message",
                "msg",
                "error.message",
                "error_msg"
            ]) ?? "响应成功，但没有匹配到余额字段"
            throw ProviderError.noBalanceDetails(details)
        }

        let generalRemain = remains.first { remain in
            DynamicJSON.firstString(in: remain, paths: ["model_name"]) == "general"
        } ?? remains.first

        let intervalSummary = generalRemain.flatMap { remain -> String? in
            if let percent = DynamicJSON.numericValues(in: remain, path: "current_interval_remaining_percent").first {
                return "5小时 \(Int(percent.rounded()))%"
            }

            let total = DynamicJSON.numericValues(in: remain, path: "current_interval_total_count").first ?? 0
            let used = DynamicJSON.numericValues(in: remain, path: "current_interval_usage_count").first ?? 0
            if total > 0 {
                return "5小时 \(Int(max(total - used, 0)))/\(Int(total))"
            }

            return nil
        }

        let weeklySummary = generalRemain.flatMap { remain -> String? in
            if let percent = DynamicJSON.numericValues(in: remain, path: "current_weekly_remaining_percent").first {
                return "周 \(Int(percent.rounded()))%"
            }
            return nil
        }
        let metrics = generalRemain.map(minimaxMetrics) ?? []

        guard intervalSummary != nil || weeklySummary != nil else {
            throw ProviderError.noBalanceDetails("响应成功，但没有可显示的配额百分比")
        }

        return UsageItem(
            id: config.id,
            name: config.name,
            kind: config.kind,
            primaryText: intervalSummary ?? weeklySummary ?? "可用",
            secondaryText: "",
            status: .ok,
            updatedAt: Date(),
            metrics: metrics
        )
    }

    private func minimaxMetrics(from remain: Any) -> [UsageMetric] {
        var metrics: [UsageMetric] = []

        if let percent = DynamicJSON.numericValues(in: remain, path: "current_interval_remaining_percent").first {
            metrics.append(UsageMetric(
                id: "minimax-interval",
                label: "5小时",
                percent: clampedPercent(percent),
                detail: minimaxResetDetail(remain, path: "remains_time")
            ))
        }

        if let percent = DynamicJSON.numericValues(in: remain, path: "current_weekly_remaining_percent").first {
            metrics.append(UsageMetric(
                id: "minimax-weekly",
                label: "周",
                percent: clampedPercent(percent),
                detail: minimaxResetDetail(remain, path: "weekly_remains_time")
            ))
        }

        return metrics
    }

    private func minimaxResetDetail(_ remain: Any, path: String) -> String {
        guard let milliseconds = DynamicJSON.numericValues(in: remain, path: path).first, milliseconds > 0 else {
            return "重置时间未知"
        }
        return "重置 \(formatDuration(milliseconds / 1000))"
    }

    private func clampedPercent(_ percent: Double) -> Double {
        min(max(percent, 0), 100)
    }

    private func minimaxQuotaURLs() -> [String] {
        if let url = config.url?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
            return [url]
        }

        return [
            "https://api.minimaxi.com/v1/api/openplatform/coding_plan/remains",
            "https://api.minimax.io/v1/api/openplatform/coding_plan/remains"
        ]
    }

    private func fetchCodexUsage() throws -> UsageItem {
        let object = try requestCodexRateLimits()
        let snapshot = DynamicJSON.values(in: object, path: "rateLimitsByLimitId.codex").first
            ?? DynamicJSON.values(in: object, path: "rateLimits").first

        guard let snapshot else {
            throw ProviderError.codexProtocol("响应中没有 rateLimits")
        }

        var metrics: [UsageMetric] = []
        for key in ["primary", "secondary"] {
            guard let window = DynamicJSON.values(in: snapshot, path: key).first,
                  let used = DynamicJSON.numericValues(in: window, path: "usedPercent").first else {
                continue
            }
            let duration = DynamicJSON.numericValues(in: window, path: "windowDurationMins").first
            let remaining = clampedPercent(100 - used)
            metrics.append(UsageMetric(
                id: "codex-\(key)",
                label: codexWindowLabel(durationMinutes: duration, fallback: key),
                percent: remaining,
                detail: codexResetDetail(window)
            ))
        }

        let unlimited = (DynamicJSON.values(in: snapshot, path: "credits.unlimited").first as? Bool) == true
        guard !metrics.isEmpty || unlimited else {
            throw ProviderError.noBalanceDetails("Codex 未返回可显示的配额窗口")
        }

        let plan = DynamicJSON.firstString(in: snapshot, paths: ["planType"])
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        var details = [plan.map { "ChatGPT \($0)" } ?? "Codex 配额"]
        if (DynamicJSON.values(in: snapshot, path: "credits.hasCredits").first as? Bool) == true,
           let balance = DynamicJSON.firstString(in: snapshot, paths: ["credits.balance"]) {
            details.append("Credits \(balance)")
        }
        if let resetCount = DynamicJSON.numericValues(in: object, path: "rateLimitResetCredits.availableCount").first,
           resetCount > 0 {
            details.append("可重置 \(Int(resetCount)) 次")
        }

        let primaryText: String
        if let first = metrics.first {
            primaryText = "\(first.label) \(Int(first.percent.rounded()))%"
        } else {
            primaryText = "无限"
        }
        let reachedType = DynamicJSON.values(in: snapshot, path: "rateLimitReachedType").first
        let warning = (reachedType != nil && !(reachedType is NSNull))
            || metrics.contains(where: { $0.percent <= 20 })

        return UsageItem(
            id: config.id,
            name: config.name,
            kind: config.kind,
            primaryText: primaryText,
            secondaryText: details.joined(separator: " · "),
            status: warning ? .warning : .ok,
            updatedAt: Date(),
            metrics: metrics
        )
    }

    private func requestCodexRateLimits() throws -> Any {
        let process = Process()
        let executableURL = try codexExecutableURL()
        process.executableURL = executableURL
        process.arguments = ["app-server", "--stdio"]

        // Finder 启动的应用通常只有最小 PATH。Codex 的 npm 启动脚本使用
        // `#!/usr/bin/env node`，因此需要显式加入 Codex 与常见 Node 目录。
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let existingPath = environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        let pathCandidates = [
            executableURL.deletingLastPathComponent().path,
            "\(home)/.local/bin",
            "\(home)/.volta/bin",
            "\(home)/.asdf/shims",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ] + existingPath
        environment["PATH"] = pathCandidates.reduce(into: [String]()) { values, path in
            if !values.contains(path) {
                values.append(path)
            }
        }.joined(separator: ":")
        process.environment = environment

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let lock = NSLock()
        let finished = DispatchSemaphore(value: 0)
        var pending = Data()
        var response: [String: Any]?
        var didFinish = false
        var errorOutput = Data()

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            lock.lock()
            pending.append(data)
            while let newline = pending.firstRange(of: Data([0x0A])) {
                let line = pending.subdata(in: pending.startIndex..<newline.lowerBound)
                pending.removeSubrange(pending.startIndex...newline.lowerBound)
                guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                      (object["id"] as? NSNumber)?.intValue == 2 else {
                    continue
                }
                response = object
                if !didFinish {
                    didFinish = true
                    finished.signal()
                }
            }
            lock.unlock()
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            lock.lock()
            if errorOutput.count < 4_096 {
                errorOutput.append(data.prefix(4_096 - errorOutput.count))
            }
            lock.unlock()
        }

        defer {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            try? inputPipe.fileHandleForWriting.close()
            if process.isRunning {
                process.terminate()
            }
        }

        try process.run()
        let messages: [[String: Any]] = [
            [
                "method": "initialize",
                "id": 1,
                "params": [
                    "clientInfo": [
                        "name": "llm_usage_bar",
                        "title": "LLMUsageBar",
                        "version": "0.1.0"
                    ]
                ]
            ],
            ["method": "initialized", "params": [:]],
            ["method": "account/rateLimits/read", "id": 2, "params": [:]]
        ]
        for message in messages {
            let data = try JSONSerialization.data(withJSONObject: message)
            inputPipe.fileHandleForWriting.write(data)
            inputPipe.fileHandleForWriting.write(Data([0x0A]))
        }

        guard finished.wait(timeout: .now() + 20) == .success else {
            lock.lock()
            let details = String(data: errorOutput, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            lock.unlock()
            throw ProviderError.codexProtocol(details?.isEmpty == false ? details! : "查询超时")
        }

        lock.lock()
        let result = response
        lock.unlock()
        guard let result else {
            throw ProviderError.codexProtocol("没有收到响应")
        }
        if let error = result["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "查询失败"
            throw ProviderError.codexProtocol(message)
        }
        guard let value = result["result"] else {
            throw ProviderError.codexProtocol("响应缺少 result")
        }
        return value
    }

    private func codexExecutableURL() throws -> URL {
        var candidates: [String] = []
        if let configured = config.command?.trimmingCharacters(in: .whitespacesAndNewlines),
           !configured.isEmpty {
            candidates.append((configured as NSString).expandingTildeInPath)
        }
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map { "\($0)/codex" })
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        candidates.append(contentsOf: [
            "\(home)/.local/bin/codex",
            "\(home)/.npm-global/bin/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ])

        if let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return URL(fileURLWithPath: path)
        }
        throw ProviderError.codexCLINotFound
    }

    private func codexWindowLabel(durationMinutes: Double?, fallback: String) -> String {
        guard let minutes = durationMinutes else {
            return fallback == "primary" ? "短期" : "长期"
        }
        if minutes >= 7 * 24 * 60 {
            let weeks = max(Int((minutes / (7 * 24 * 60)).rounded()), 1)
            return weeks == 1 ? "周" : "\(weeks)周"
        }
        if minutes >= 24 * 60 {
            return "\(Int((minutes / (24 * 60)).rounded()))天"
        }
        return "\(Int((minutes / 60).rounded()))小时"
    }

    private func codexResetDetail(_ window: Any) -> String {
        guard let timestamp = DynamicJSON.numericValues(in: window, path: "resetsAt").first else {
            return "重置时间未知"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }

    private func fetchHTTPJSON() async throws -> UsageItem {
        guard let url = config.url else {
            throw ProviderError.missingURL
        }
        let request = try makeRequest(
            urlString: url,
            method: config.method ?? "GET",
            headers: config.headers ?? [:],
            body: config.body
        )
        let object = try await requestJSON(request)
        guard let rawValue = DynamicJSON.firstString(in: object, paths: config.valuePaths ?? []) else {
            throw ProviderError.noBalance
        }

        let currency = config.currency.map { "\($0) " } ?? ""
        return UsageItem(
            id: config.id,
            name: config.name,
            kind: config.kind,
            primaryText: "\(currency)\(formatDecimal(rawValue))",
            secondaryText: "通用 HTTP 适配器",
            status: .ok,
            updatedAt: Date()
        )
    }

    private func fetchAliyunBalance() throws -> UsageItem {
        let candidates = [
            "/opt/homebrew/bin/aliyun",
            "/usr/local/bin/aliyun",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/aliyun"
        ]
        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw ProviderError.aliyunCLINotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["bssopenapi", "QueryAccountBalance", "--RegionId", "cn-hangzhou"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            throw ProviderError.commandFailed(process.terminationStatus, output)
        }

        let display = parseCommandDisplay(output)
        return UsageItem(
            id: config.id,
            name: config.name,
            kind: config.kind,
            primaryText: display.primary,
            secondaryText: display.secondary,
            status: .ok,
            updatedAt: Date()
        )
    }

    private func makeRequest(
        urlString: String,
        method: String,
        headers: [String: String],
        body: String?
    ) throws -> URLRequest {
        guard let url = URL(string: urlString) else {
            throw ProviderError.invalidURL(urlString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        for (key, value) in headers {
            request.setValue(try resolveSecret(value), forHTTPHeaderField: key)
        }
        if let body {
            request.httpBody = body.data(using: .utf8)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        return request
    }

    private func authHeaders() -> [String: String] {
        var headers = config.headers ?? [:]
        guard let rawKey = config.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawKey.isEmpty else {
            return headers
        }

        headers["Authorization"] = rawKey.hasPrefix("Bearer ") ? rawKey : "Bearer \(rawKey)"
        return headers
    }

    private func requestJSON(_ request: URLRequest) async throws -> Any {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data.prefix(300), encoding: .utf8) ?? ""
            throw ProviderError.httpStatus(http.statusCode, body)
        }
        return try DynamicJSON.object(from: data)
    }

    private func resolveSecret(_ value: String) throws -> String {
        let marker = "env:"
        guard let range = value.range(of: marker) else {
            return value
        }

        let name = String(value[range.upperBound...])
        guard let secret = ProcessInfo.processInfo.environment[name], !secret.isEmpty else {
            throw ProviderError.missingHeaderToken(name)
        }

        return value.replacingCharacters(in: range.lowerBound..<value.endIndex, with: secret)
    }

    private func parseCommandDisplay(_ output: String) -> (primary: String, secondary: String) {
        if let data = output.data(using: .utf8),
           let object = try? DynamicJSON.object(from: data),
           let raw = DynamicJSON.firstString(in: object, paths: config.valuePaths ?? ["balance", "data.balance", "Data.AvailableAmount", "AvailableAmount"]) {
            let currency = config.currency.map { "\($0) " } ?? ""
            return ("\(currency)\(formatDecimal(raw))", commandSecondaryText)
        }

        let firstLine = output.split(separator: "\n").first.map(String.init) ?? "无输出"
        return (firstLine, commandSecondaryText)
    }

    private var commandSecondaryText: String {
        if config.id == "aliyun-bailian" {
            return "余额可用"
        }
        return "命令适配器"
    }

    private func formatDecimal(_ value: String) -> String {
        guard let number = Double(value) else {
            return value
        }
        return formatNumber(number)
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let totalMinutes = max(Int(seconds.rounded(.down)) / 60, 0)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return "\(days)d \(hours)h"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
