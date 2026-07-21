import SwiftUI

struct UsagePanelView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let error = store.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            } else if store.items.isEmpty {
                EmptyProvidersView()
            } else {
                VStack(spacing: 8) {
                    ForEach(store.items) { item in
                        UsageRow(item: item)
                    }
                }
            }

            Divider()

            HStack {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(store.isRefreshing)

                Button {
                    SettingsWindowPresenter.shared.show(store: store)
                } label: {
                    Label("设置", systemImage: "gearshape")
                }

                Spacer()

                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
    }

    private var header: some View {
        HStack {
            Text(lastRefreshText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if store.isRefreshing {
                ProgressView()
                    .scaleEffect(0.65)
                    .frame(width: 18, height: 18)
            }
        }
    }

    private var lastRefreshText: String {
        guard let date = store.lastRefresh else {
            return "尚未刷新"
        }
        return "上次刷新 \(date.formatted(date: .omitted, time: .standard))"
    }
}

struct EmptyProvidersView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("没有启用的服务")
                .font(.callout.weight(.medium))
            Text("编辑配置文件后重新载入。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }
}

struct UsageRow: View {
    let item: UsageItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                ProviderLogo(kind: item.kind, name: item.name, size: 30)
                Image(systemName: item.status.symbolName)
                    .font(.system(size: 10, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(color, .white)
                    .background(Circle().fill(.regularMaterial))
                    .offset(x: 3, y: 3)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.name)
                        .font(.callout.weight(.medium))
                    Spacer(minLength: 12)
                    if item.metrics.isEmpty {
                        Text(item.primaryText)
                            .font(.callout.monospacedDigit().weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .allowsTightening(true)
                    }
                }

                if item.metrics.isEmpty {
                    Text(item.secondaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(item.metrics) { metric in
                            UsageMetricBar(metric: metric)
                        }
                        if !item.secondaryText.isEmpty {
                            Text(item.secondaryText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 3)
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    private var color: Color {
        switch item.status {
        case .idle: .secondary
        case .loading: .accentColor
        case .ok: .green
        case .warning: .orange
        case .failed: .red
        }
    }
}

struct UsageMetricBar: View {
    let metric: UsageMetric

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 0) {
            GridRow {
                Text(metric.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .leading)

                ProgressView(value: metric.percent, total: 100)
                    .progressViewStyle(.linear)
                    .tint(metric.percent <= 20 ? .orange : .green)
                    .frame(height: 6)

                Text("\(Int(metric.percent.rounded()))%")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(metric.percent <= 20 ? .orange : .green)
                    .frame(width: 42, alignment: .trailing)

                Text(metric.detail)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(width: 90, alignment: .leading)
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @State private var draft = AppConfig.sample
    @State private var selectedProviderID: String?
    @State private var saveMessage: String?
    @State private var saveError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                providerList
                    .frame(width: 232)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))

                Divider()

                if let binding = selectedProviderBinding {
                    ProviderEditor(provider: binding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EmptyProvidersView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(24)
                }
            }

            Divider()

            HStack {
                if let saveError {
                    Label(saveError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                } else if let saveMessage {
                    Label(saveMessage, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer()

                Button {
                    store.openConfigFolder()
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.bordered)
                .help("打开配置目录")

                Button {
                    saveDraft()
                } label: {
                    Label("保存并刷新", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s", modifiers: .command)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .onAppear(perform: resetDraft)
    }

    private var providerList: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("服务")
                    .font(.title3.weight(.semibold))
                Text("已启用 \(draft.providers.filter(\.enabled).count) / \(draft.providers.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            List(selection: $selectedProviderID) {
                ForEach(draft.providers) { provider in
                    ProviderListRow(provider: provider)
                        .padding(.vertical, 3)
                    .tag(provider.id)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            RefreshIntervalControl(value: $draft.refreshSeconds)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
    }

    private var selectedProviderBinding: Binding<ProviderConfig>? {
        guard let selectedProviderID,
              let index = draft.providers.firstIndex(where: { $0.id == selectedProviderID }) else {
            return nil
        }

        return Binding(
            get: { draft.providers[index] },
            set: { draft.providers[index] = $0 }
        )
    }

    private func resetDraft() {
        draft = store.config
        selectedProviderID = draft.providers.first?.id
        saveMessage = nil
        saveError = nil
    }

    private func saveDraft() {
        do {
            try store.saveConfig(draft)
            saveMessage = "已保存"
            saveError = nil
            Task { await store.refresh() }
        } catch {
            saveError = error.localizedDescription
            saveMessage = nil
        }
    }

}

struct ProviderListRow: View {
    let provider: ProviderConfig

    var body: some View {
        HStack(spacing: 10) {
            ProviderLogo(kind: provider.kind, name: provider.name, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(provider.id == "aliyun-bailian" ? "阿里云百炼余额" : provider.kind.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Circle()
                .fill(provider.enabled ? Color.green : Color.secondary.opacity(0.35))
                .frame(width: 7, height: 7)
                .help(provider.enabled ? "已启用" : "未启用")
        }
    }
}

struct RefreshIntervalControl: View {
    @Binding var value: TimeInterval

    private let options: [(seconds: TimeInterval, title: String)] = [
        (30, "30 秒"),
        (60, "1 分钟"),
        (300, "5 分钟"),
        (600, "10 分钟"),
        (900, "15 分钟"),
        (1_800, "30 分钟"),
        (3_600, "1 小时")
    ]

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.secondary)
            Text("自动刷新")
                .font(.caption.weight(.medium))
            Spacer()
            Picker("", selection: $value) {
                ForEach(options, id: \.seconds) { option in
                    Text(option.title).tag(option.seconds)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: 88)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct LogoMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(Color(red: 0.11, green: 0.13, blue: 0.17))
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(Color(red: 0.18, green: 0.21, blue: 0.27))
                .padding(size * 0.12)

            HStack(alignment: .bottom, spacing: size * 0.08) {
                RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                    .fill(.white)
                    .frame(width: size * 0.16, height: size * 0.34)
                RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                    .fill(Color(red: 0.22, green: 0.76, blue: 0.69))
                    .frame(width: size * 0.16, height: size * 0.56)
                RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                    .fill(Color(red: 0.11, green: 0.58, blue: 0.54))
                    .frame(width: size * 0.16, height: size * 0.45)
            }
            .offset(y: size * 0.03)

            Circle()
                .fill(Color(red: 0.22, green: 0.76, blue: 0.69))
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(x: size * 0.17, y: -size * 0.17)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct ProviderLogo: View {
    let kind: ProviderKind
    let name: String
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(imageName == "openai-icon" ? Color.white : Color(nsColor: .controlBackgroundColor))

            if let providerImage {
                Image(nsImage: providerImage)
                    .renderingMode(imageName == "openai-icon" ? .template : .original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(imageName == "openai-icon" ? Color.black : Color.primary)
                    .padding(size * 0.17)
            } else {
                fallbackMark
                    .padding(size * 0.12)
            }

            RoundedRectangle(cornerRadius: size * 0.20, style: .continuous)
                .strokeBorder(.secondary.opacity(0.18), lineWidth: 1)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(name) logo")
    }

    private var imageName: String? {
        switch kind {
        case .deepseekBalance:
            return "deepseek-icon"
        case .minimaxBalance:
            return "minimax-icon"
        case .codexUsage, .openAIMonthlyCost:
            return "openai-icon"
        case .command:
            if name.localizedCaseInsensitiveContains("阿里") || name.localizedCaseInsensitiveContains("aliyun") {
                return "aliyun-bailian-icon"
            }
            return nil
        case .httpJSON:
            return nil
        }
    }

    private var providerImage: NSImage? {
        guard let imageName,
              let url = Bundle.module.url(forResource: imageName, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private var fallbackMark: some View {
        Image(systemName: fallbackSymbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private var fallbackSymbol: String {
        switch kind {
        case .codexUsage, .openAIMonthlyCost: "sparkles"
        case .httpJSON: "curlybraces"
        case .command: "terminal"
        case .deepseekBalance, .minimaxBalance: "app.dashed"
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.separator.opacity(0.35), lineWidth: 0.5)
            }
        }
    }
}

struct SettingsField<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 0) {
            GridRow {
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 92, alignment: .leading)
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct ProviderEditor: View {
    @Binding var provider: ProviderConfig

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
                .padding(.horizontal, 24)
                .padding(.vertical, 18)

            Divider()

            Form {
                Section("基本信息") {
                    SettingsField("显示名称") {
                        TextField("", text: $provider.name)
                    }
                    if showsCurrency {
                        SettingsField("币种") {
                            HStack {
                                Picker("", selection: currencyBinding) {
                                    Text("人民币 CNY").tag("CNY")
                                    Text("美元 USD").tag("USD")
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                                .frame(width: 220)
                                Spacer()
                            }
                        }
                    }
                }

                switch provider.kind {
                case .deepseekBalance:
                    Section("API Key") {
                        apiKeyEditor
                        credentialHint
                    }
                case .minimaxBalance:
                    Section("API Key") {
                        apiKeyEditor
                        credentialHint
                    }
                case .codexUsage:
                    Section("Codex CLI") {
                        SettingsField("可执行文件") {
                            TextField("", text: optionalText($provider.command), prompt: Text("自动查找"))
                        }
                        Text("使用 Codex CLI 已保存的 ChatGPT 登录状态；首次使用前请运行 codex login。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .openAIMonthlyCost:
                    Section("API Key 与预算") {
                        apiKeyEditor
                        SettingsField("月预算") {
                            HStack(spacing: 8) {
                                TextField("", value: optionalDouble($provider.monthlyBudget), format: .number)
                                    .frame(width: 140)
                                Text(provider.currency ?? "USD")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text("月预算留空时显示本月累计组织 API 成本。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .httpJSON:
                    Section("HTTP 请求") {
                        providerHTTPFields(defaultURL: nil, showURL: true)
                        valuePathsEditor
                        bodyEditor
                    }
                case .command:
                    Section("阿里云 CLI") {
                        Text("使用本机阿里云 CLI 查询百炼账户余额，无需手动配置命令。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }

    private var editorHeader: some View {
        HStack(spacing: 14) {
            ProviderLogo(kind: provider.kind, name: provider.name, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(provider.name.isEmpty ? "未命名服务" : provider.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(providerTypeName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("启用", isOn: $provider.enabled)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.bottom, 2)
    }

    private var providerTypeName: String {
        provider.id == "aliyun-bailian" ? "阿里云百炼余额" : provider.kind.displayName
    }

    private var credentialHint: some View {
        Text("可以直接填写，或使用 env:VARIABLE 引用环境变量。")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var showsCurrency: Bool {
        switch provider.kind {
        case .openAIMonthlyCost, .httpJSON, .command:
            return true
        case .deepseekBalance, .minimaxBalance, .codexUsage:
            return false
        }
    }

    private var currencyBinding: Binding<String> {
        Binding(
            get: {
                if provider.currency == "USD" {
                    return "USD"
                }
                return "CNY"
            },
            set: { provider.currency = $0 }
        )
    }

    private var apiKeyEditor: some View {
        SettingsField("密钥") {
            SecureField("", text: optionalText($provider.apiKey))
                .textContentType(.password)
        }
    }

    @ViewBuilder
    private func providerHTTPFields(defaultURL: String?, showURL: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if showURL {
                SettingsField("URL") {
                    TextField("", text: optionalText($provider.url), prompt: Text(defaultURL ?? "https://example.com/balance"))
                }
            }

            SettingsField("Method") {
                Picker("", selection: optionalText($provider.method)) {
                    Text("GET").tag("GET")
                    Text("POST").tag("POST")
                    Text("PUT").tag("PUT")
                    Text("PATCH").tag("PATCH")
                }
                .labelsHidden()
                .frame(width: 120)
            }

            Text("Headers")
                .font(.callout.weight(.medium))
            TextEditor(text: headersText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 90)
                .scrollContentBackground(.hidden)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var valuePathsEditor: some View {
        SettingsField("JSON 路径") {
            TextField("", text: valuePathsText, prompt: Text("data.balance, balance"))
        }
    }

    private var bodyEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Body")
                .font(.callout.weight(.medium))
            TextEditor(text: optionalText($provider.body))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 90)
                .scrollContentBackground(.hidden)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var commandEditor: some View {
        SettingsField("命令") {
            TextField("", text: optionalText($provider.command), prompt: Text("aliyun bssopenapi QueryAccountBalance"))
        }
    }

    private var headersText: Binding<String> {
        Binding(
            get: {
                (provider.headers ?? [:])
                    .sorted { $0.key < $1.key }
                    .map { "\($0.key): \($0.value)" }
                    .joined(separator: "\n")
            },
            set: { text in
                var headers: [String: String] = [:]
                for line in text.split(whereSeparator: \.isNewline) {
                    let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
                    guard parts.count == 2 else { continue }
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty {
                        headers[key] = value
                    }
                }
                provider.headers = headers.isEmpty ? nil : headers
            }
        )
    }

    private var valuePathsText: Binding<String> {
        Binding(
            get: { (provider.valuePaths ?? []).joined(separator: ", ") },
            set: { text in
                let paths = text
                    .split { $0 == "," || $0.isNewline }
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                provider.valuePaths = paths.isEmpty ? nil : paths
            }
        )
    }

    private func optionalText(_ binding: Binding<String?>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue ?? "" },
            set: { binding.wrappedValue = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }

    private func optionalDouble(_ binding: Binding<Double?>) -> Binding<Double?> {
        Binding(
            get: { binding.wrappedValue },
            set: { binding.wrappedValue = $0 }
        )
    }
}
