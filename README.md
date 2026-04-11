# MiniMax Status Bar

**macOS menu-bar “glance tool” for MiniMax Token Plan quotas** — built for developers who run **M2.7** all day via OpenClaw, Cursor, Claude Code, etc. You see **remaining %**, **reset ETA**, and **per-modality** limits without opening the console.

中文：**MiniMax Token Plan 用量感知工具**。菜单栏一眼看主力剩余与颜色状态；点开看各模态（文本 / 语音 / 视频 / 音乐 / 图片）的剩余与重置时间。零打扰（LSUIElement）、零配置（自动读 OpenClaw 与环境变量）。

---

## 要求 / Requirements

- **macOS 13.0+**
- **Token Plan** API key（`sk-…` / 常见 `sk-cp-…`），与普通 Open Platform Key 不同  
- UI 为 **系统一致的原生材质与圆角**（全版本统一、可复现构建）；若未来 CI/SDK 升级，可在不牺牲旧系统的前提下再接入 Liquid Glass 增强

---

## 功能 / Features


| 能力        | 说明                                                                                                       |
| --------- | -------------------------------------------------------------------------------------------------------- |
| **瞟一眼**   | 菜单栏 **颜色点 + 主力缩写**（如 `2.7·72%`）；悬停 **Tooltip** 含模型名、剩余 %、**重置倒计时**（两次拉取之间每 30s 刷新文案）                     |
| **主力优先**  | 与控制台一致的 **「剩余」** 语义；列表行同时展示 **剩余 %** 与 **已用 %**；周配额展示「剩余 / 限额」与「本周已用」                                    |
| **多模态**   | 按 Text / Speech / Video / Music / Image 分组；适合同时盯多条产品线的开发者                                                |
| **零配置**   | 按顺序读取 `MINIMAX_API_KEY` → `~/.openclaw/.env` → `~/.openclaw/openclaw.json`；保存后点 **「重新检测密钥」** 即可，无需重启 App |
| **首次体验**  | 无 Key / Key 格式不对时显示 **引导页**（打开控制台、打开 OpenClaw 目录、重试），而不是一屏错误堆栈                                           |
| **低配额通知** | 仅对 **菜单栏同款主力模型** 推送一次式提醒（含重置提示）；回到较安全水位后才会再次允许提醒                                                         |
| **自动更新**  | 检测 GitHub Releases，一键下载 DMG 并替换、重启                                                                       |
| **开机启动**  | 使用 `SMAppService`（macOS 13+）                                                                             |


---

## 安装 / Installation

### 下载 Release

1. 打开 [GitHub Releases](https://github.com/victor0602/minimax-status-bar/releases)，下载 **v1.1.1**（或最新）的 `.dmg`
2. 打开 DMG，将 **MiniMax Status Bar** 拖入 **应用程序**
3. 若提示无法打开：**系统设置 → 隐私与安全性 → 仍要打开**

若提示「文件已损坏」：

```bash
xattr -cr "/Applications/MiniMax Status Bar.app"
```

---

## 配置 API Key

1. 环境变量 `MINIMAX_API_KEY`
2. `~/.openclaw/.env` 中的 `MINIMAX_API_KEY=…`
3. `~/.openclaw/openclaw.json` 中 `models.providers.minimax.apiKey` 或 `env.MINIMAX_API_KEY`

```bash
# 环境变量示例
export MINIMAX_API_KEY="your_token_plan_key"

# 或写入 OpenClaw
mkdir -p ~/.openclaw
echo 'MINIMAX_API_KEY=your_token_plan_key' > ~/.openclaw/.env
```

---

## 使用

1. 启动 App → 菜单栏出现图标与 **剩余比例**（主力为 M2.7 时带 `2.7·` 前缀）
2. 点击图标 → popover 中查看各模型 **剩余 / 已用**、**重置倒计时**
3. `⌘R` 或刷新按钮手动拉取
4. 有新版本时底部 **「更新」** 自动下载安装并重启

---

## 从源码构建

依赖 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。修改 `project.yml` 后执行 `xcodegen generate` 再打开工程。

```bash
git clone https://github.com/victor0602/minimax-status-bar.git
cd minimax-status-bar
xcodegen generate
xcodebuild -project minimax-status-bar.xcodeproj -scheme minimax-status-bar -configuration Debug build
```

### 单元测试

```bash
xcodegen generate
xcodebuild -project minimax-status-bar.xcodeproj -scheme minimax-status-bar -configuration Debug test CODE_SIGNING_ALLOWED=NO -destination 'platform=macOS'
```

---

## API

- **配额接口（国内）**: `https://api.minimaxi.com/v1/api/openplatform/coding_plan/remains`
- **控制台**: [Token Plan](https://platform.minimaxi.com/user-center/payment/token-plan)

---

## Changelog

### v1.1.1

- 菜单栏：**主力缩写**（如 `2.7·`）+ Tooltip 含 **剩余 %** 与 **重置倒计时**；30s 本地刷新 Tooltip（两次 API 之间）
- 通知：**仅主力模型** 低配额提醒，正文含重置提示；10–19% 区间重置提醒状态，避免长期卡在低位无法再次提醒
- 首次体验：`SetupGuidanceView` 引导；`APIKeyResolver` 抽离；支持 **重新检测** 密钥无需重启
- 数据：`ModelQuota` 字段语义厘清（剩余 / 已用 / 周维度），UI 明确标注
- 更新流程：`UpdateFileDownloader` + `ReleaseDMGInstaller`（`hdiutil`/`cp` 使用 `Process` 参数数组）
- 稳定性：轮询 Timer 使用 `RunLoop.common`；下载 delegate **单次完成**；配额请求 **超时**
- 测试：`minimax-status-barTests`；XCTest 宿主下跳过单实例 `exit(0)` 逻辑

### v1.1.0 及更早

见 [Releases](https://github.com/victor0602/minimax-status-bar/releases) 页面说明。

---

## 技术栈

- Swift / SwiftUI、AppKit `NSPopover`、`NSStatusItem`
- XcodeGen、`ObservableObject`、async/await

---

## License

MIT License