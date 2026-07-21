# Contributing

欢迎提交 Issue 和 Pull Request。

## 本地开发

要求 macOS 13+、Swift 5.9+ 和 Python 3/Pillow（仅打包图标时需要）。

```bash
swift build
swift run LLMUsageBar
```

打包应用：

```bash
python3 -m pip install pillow
scripts/build_app.sh
```

## 提交约定

- 一个 Pull Request 聚焦一个问题。
- UI 变化请附截图。
- 新的响应解析逻辑应附测试或脱敏后的响应示例。
- 不要提交 API Key、Codex 登录文件或阿里云凭据。
