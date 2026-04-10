# MiniMax Status Bar

A macOS menu bar app for monitoring MiniMax API token usage in real-time.

---

## 要求 / Requirements

- **macOS 13.0 or later**
  - Liquid Glass UI on macOS 26+
  - Fallback design on macOS 13–25

---

## 功能 / Features

- Real-time API usage monitoring / 实时 API 用量监控
- Support for multiple model categories (Text, Speech, Video, Music, Image) / 支持多模型分类
- Liquid Glass UI design on macOS 26+, native fallback on older versions / macOS 26+ 液态玻璃 UI
- Automatic refresh with live countdown / 自动刷新 + 倒计时
- Color-coded status indicators (green/yellow/red) / 颜色状态指示（绿/黄/红）
- One-click console access / 一键打开控制台
- Auto-update from GitHub Releases / 自动从 GitHub Releases 更新

---

## 安装 / Installation

### 下载 Release / Download Release

1. Download the `.dmg` file from [GitHub Releases](https://github.com/victor0602/minimax-status-bar/releases)
2. Open the DMG and drag **MiniMax Status Bar** into **Applications**
3. On first launch, if you see a security warning, go to **System Settings → Privacy & Security → Still Open**

If installation shows "file damaged"（如果安装时提示文件已损坏）:
```bash
xattr -cr "/Applications/MiniMax Status Bar.app"
```

---

### 配置 API Key / Configure API Key

The app automatically resolves the API key from multiple sources (in priority order):

App 自动从以下来源按优先级读取 API Key：

1. Environment variable `MINIMAX_API_KEY` / 环境变量 `MINIMAX_API_KEY`
2. `~/.openclaw/.env` — looks for `MINIMAX_API_KEY=sk-...` / 查找 `MINIMAX_API_KEY=sk-...`
3. `~/.openclaw/openclaw.json` — looks for `models.providers.minimax.apiKey` or `env.MINIMAX_API_KEY`

**OpenClaw 用户 / OpenClaw users:** 在 OpenClaw 中配置好 MiniMax 后直接启动 app，无需额外配置。

**其他用户 / Other users:** Choose one of the following / 选择以下方式之一：

```bash
# 方式 1: 环境变量（推荐）
echo 'export MINIMAX_API_KEY="your_key_here"' >> ~/.zshrc
source ~/.zshrc

# 方式 2: .env 文件
mkdir -p ~/.openclaw
echo 'MINIMAX_API_KEY=your_key_here' > ~/.openclaw/.env
```

If no key is found, the app displays a friendly error with setup instructions.
如果未找到 Key，app 会显示配置说明。

---

### 从源码构建 / Build from Source

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen). After any project file changes, run `xcodegen generate` to regenerate the `.xcodeproj`.

```bash
git clone https://github.com/victor0602/minimax-status-bar.git
cd minimax-status-bar
xcodegen generate
xcodebuild -project minimax-status-bar.xcodeproj -scheme minimax-status-bar -configuration Debug build
```

---

## 使用 / Usage

1. Launch the app / 启动 app
2. Click the menu bar icon to view API usage / 点击菜单栏图标查看用量
3. Click refresh button or press `Cmd+R` to manually refresh / 点击刷新按钮或按 `Cmd+R`
4. View remaining quota and reset time for each model / 查看剩余配额和重置时间
5. Click "Update" button when a new version is available — the app will download, install, and restart automatically / 有新版本时点击"更新"按钮，app 自动下载安装并重启

---

## API Endpoint

- **CN Region**: `https://api.minimaxi.com/v1/api/openplatform/coding_plan/remains`
- **Console**: `https://platform.minimaxi.com/user-center/payment/token-plan`

---

## 技术栈 / Architecture

- **SwiftUI** — UI framework with Liquid Glass design (macOS 26+)
- **NSPopover** — Menu bar popover for displaying content
- **ObservableObject** — State management (compatible with macOS 13+)

---

## License

MIT License
