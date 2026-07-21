# Security

## 报告漏洞

请不要公开提交包含凭据、认证响应或可利用细节的 Issue。请通过 GitHub Security Advisory 私下报告安全问题。

## 凭据说明

LLMUsageBar 不会把用户配置提交到仓库或远程服务。当前版本将 DeepSeek 和 MiniMax API Key 保存在本机：

```text
~/.llm-usage-bar/config.json
```

该文件目前不是 Keychain 存储，请确保本机账户和文件权限安全。也可配置 `env:VARIABLE`，但从 Finder 启动时需要通过 `launchd` 等方式提供环境变量。

Codex 登录状态由官方 Codex CLI 管理；应用不会读取或保存 Codex Token。阿里云凭据由官方 `aliyun` CLI 管理。
