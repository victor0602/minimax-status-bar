# MiniMax Status Bar — 项目架构文档

> 本文档供 AI 助手快速理解项目全局规范和架构。以后开启任何新的 AI 会话时，让 AI 读取此文档即可。

---

## 一、项目概览

| 属性 | 说明 |
|------|------|
| **项目名称** | MiniMax Status Bar |
| **类型** | macOS 菜单栏工具（LSUIElement App，无 Dock 图标） |
| **技术栈** | Swift 5.9 · SwiftUI · AppKit · SQLite.swift 0.15.3 |
| **最低 macOS** | 13.0 |
| **构建工具** | XcodeGen |
| **当前版本** | v2.0.3（Build 8） |
| **定位** | 为重度使用 MiniMax M2.7 Token Plan 的开发者提供菜单栏配额感知与用量追踪 |

---

## 二、目录结构

```
minimax-status-bar/
├── Sources/
│   ├── App/                    # 应用入口与生命周期
│   │   ├── main.swift          # 手动启动 NSApplication，单实例检查
│   │   ├── AppDelegate.swift   # 生命周期管理、通知代理、设置窗口
│   │   └── Info.plist          # CFBundle 配置（LSUIElement=true）
│   ├── Config/
│   │   └── AppConfig.swift     # GitHub 仓库名、UserDefaults 键枚举
│   ├── Models/                 # 数据模型
│   │   ├── ModelQuota.swift   # 核心模型：配额数据 + API Raw JSON 结构
│   │   ├── QuotaState.swift   # ObservableObject 单一数据源
│   │   ├── PersistedModelQuota.swift  # Codable 版本，用于 UserDefaults
│   │   ├── AppError.swift      # 统一错误类型（API/网络/未知）
│   │   ├── SetupReason.swift  # 首次引导状态
│   │   ├── UpdateState.swift   # 更新状态（检查/下载/安装/重启）
│   │   ├── UsageRecord.swift   # 用量历史（日/周/月/年聚合）
│   │   └── ReleaseInfo.swift   # GitHub Release 元信息
│   ├── Services/               # 业务服务层
│   │   ├── MiniMaxAPIService.swift     # MiniMax Token Plan API 实现
│   │   ├── APIServiceProtocol.swift    # API 抽象协议（用于 Mock 测试）
│   │   ├── APIKeyService.swift          # API Key 统一入口
│   │   ├── APIKeyResolver.swift         # 三级密钥解析（env/.env/.json）
│   │   ├── APIConfigService.swift       # 超时/请求ID配置
│   │   ├── APIMetrics.swift             # API 耗时/错误记录
│   │   ├── NetworkMonitor.swift          # NWPathMonitor 网络恢复监听
│   │   ├── NotificationService.swift     # 低配额三段通知 + 更新通知
│   │   ├── UpdateService.swift          # GitHub Releases 版本检查（actor）
│   │   ├── UpdateFileDownloader.swift    # 带进度的文件下载
│   │   ├── ReleaseDMGInstaller.swift    # DMG 挂载/复制/安装流程
│   │   ├── QuotaStatePersistence.swift  # 缓存抽象协议 + UserDefaults 实现
│   │   ├── CacheConsistencyChecker.swift # 校验和/一致性检查
│   │   ├── UsageHistoryRecorder.swift   # 每次成功拉取后记录快照
│   │   ├── UsageHistorySQLiteStore.swift # SQLite 历史存储
│   │   ├── ExportService.swift          # CSV 导出
│   │   └── LaunchAtLoginService.swift   # 开机启动（SMAppService）
│   └── UI/
│       ├── StatusBarController.swift     # 核心编排器：Timer/API/刷新/UI
│       ├── MenuContentView.swift         # NSPopover SwiftUI 容器
│       ├── DetailView.swift              # 主下拉面板容器
│       ├── SetupGuidanceView.swift       # 首次配置引导
│       ├── PopoverChrome.swift           # 动画/格式化常量
│       ├── GlassAppliers.swift           # 玻璃/按钮/卡片视觉样式
│       ├── PlatformViewModifiers.swift   # ifPlatform* 条件修饰器
│       ├── Settings/
│       │   └── SettingsView.swift         # 设置窗口（通用/用量历史 Tab）
│       └── Components/
│           ├── HeaderBarView.swift
│           ├── BottomBarView.swift
│           ├── ModelRowView.swift
│           ├── CategoryCardListView.swift
│           ├── SkeletonRowView.swift
│           ├── OfflineBannerView.swift
│           ├── LastUpdatedLineView.swift
│           ├── DetailEmptyStateView.swift
│           ├── AboutPanelView.swift
│           ├── DownloadingUpdateOverlayView.swift
│           └── UsageHistoryPanelView.swift
├── Tests/                          # 单元测试（13个文件，70+用例）
├── Resources/
│   ├── Assets.xcassets/
│   │   ├── AppIcon.appiconset/   # App 图标（全尺寸）
│   │   └── StatusBarIcon.imageset/ # 菜单栏图标（template 渲染）
│   └── github-mark.png            # GitHub Logo（HeaderBarView 按钮回退）
├── docs/                           # 设计文档与规划
├── scripts/
│   ├── build-dmg.sh              # DMG 构建脚本
│   └── ExportOptions.plist        # xcodebuild export 选项
├── project.yml                    # XcodeGen 项目配置
└── README.md
```

---

## 三、技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| **语言** | Swift 5.9 | 最低 macOS 13.0 |
| **UI 框架** | SwiftUI + AppKit | SwiftUI 做视图，AppKit 做菜单栏容器 |
| **持久化** | SQLite.swift 0.15.3 | 用量历史存储 |
| **构建** | XcodeGen | `xcodegen generate` |
| **签名** | Ad-hoc（CI）/ 开发签名（本地） | CODE_SIGNING_ALLOWED=NO |
| **CI/CD** | GitHub Actions | Tag push 触发自动构建 DMG |
| **通知** | UNUserNotificationCenter | 低配额告警 + 更新通知 |
| **网络监控** | NWPathMonitor | 网络状态监听 |
| **开机启动** | SMAppService | macOS 13+ 原生支持 |

---

## 四、入口与初始化流程

```
main.swift
  └── NSApplication.shared.setActivationPolicy(.accessory)
        └── AppDelegate.applicationDidFinishLaunching
              ├── StatusBarController()           ← 核心初始化
              │   ├── QuotaState(persistence)
              │   ├── APIKeyService.resolve()      # 解析 API Key
              │   ├── MiniMaxAPIService            # 如果 key 有效
              │   ├── NSStatusItem + NSPopover     # 菜单栏 UI
              │   ├── startPolling()               # 启动轮询 Timer
              │   ├── startUpdateTimer(6h)         # 启动更新检查 Timer
              │   ├── NetworkMonitor.start()        # 监听网络恢复
              │   └── NSWorkspace.didWakeNotification  # 睡眠唤醒刷新
              └── NotificationService.requestPermission()
```

### 单实例检查

`main.swift` 通过 `NSSocketName` 检查是否已存在实例（XCTest 场景跳过），避免多实例冲突。

---

## 五、配置管理

### API Key 解析优先级（低 → 高）

```
1. 环境变量 MINIMAX_API_KEY
2. ~/.openclaw/.env 中的 MINIMAX_API_KEY=
3. ~/.openclaw/openclaw.json 中 models.providers.minimax.apiKey
                         或 env.MINIMAX_API_KEY
```

**格式要求**: Token Plan Key 以 `sk-cp-` 开头，长度 ≥ 40 字符

### UserDefaults 存储键（`AppConfig.swift`）

| 键 | 类型 | 说明 |
|----|------|------|
| `refreshInterval` | Int | 轮询间隔（秒），默认 60 |
| `menuBarDisplayMode` | String | 简洁/详细模式 |
| `notificationsEnabled` | Bool | 通知开关 |
| `autoCheckUpdates` | Bool | 自动检查更新 |
| `launchAtLogin` | Bool | 开机启动 |
| `requestIDEnabled` | Bool | 请求 ID 开关 |
| `apiTimeout` | Double | API 超时秒数 |
| `cachedModels` | Data | Codable 缓存 |
| `cachedChecksum` | String | 缓存校验和 |

---

## 六、核心机制

### 6.1 单一数据源（QuotaState）

`QuotaState` 是全局唯一的 `@MainActor ObservableObject`，是 UI 的单一数据源：

```swift
@MainActor
class QuotaState: ObservableObject {
    @Published var models: [ModelQuota] = []
    @Published var isLoading: Bool = false
    @Published var lastError: AppError?
    @Published var lastUpdatedAt: Date?
    @Published var setupReason: SetupReason?     // nil = 已配置
    @Published var primaryModel: ModelQuota?      // 主力模型（M2.7 优先）
}
```

所有 UI 通过 `@ObservedObject` 绑定 `QuotaState`，确保状态一致性。

### 6.2 依赖注入

- `QuotaState` 持有 `QuotaStatePersistence`（可替换，适合 Mock 测试）
- `StatusBarController` 持有 `any APIServiceProtocol`（协议化，便于注入 Mock）

### 6.3 协议抽象

| 协议 | 实现 | 用途 |
|------|------|------|
| `APIServiceProtocol` | `MiniMaxAPIService` / `MockQuotaAPIService` | API 层可测试 |
| `QuotaStatePersistence` | `UserDefaultsQuotaPersistence` / `MockQuotaPersistence` | 缓存层可测试 |

### 6.4 Actor 隔离

`UpdateService` 是 `actor`，避免并发访问 GitHub Releases 数据时的竞争条件。

### 6.5 统一错误类型

```swift
enum AppError: LocalizedError {
    case api(MiniMaxAPIError)      // API 返回错误
    case networkUnavailable          // 网络不可达
    case unknown(Error)              // 其他错误
}
```

---

## 七、轮询与重试机制

| 事件 | 行为 |
|------|------|
| 正常轮询 | 每 30/60/120/300s（用户可配置） |
| 失败重试 | 指数退避：2s → 4s → 8s，最多 3 次 |
| 低配额时 | 自动缩短至 10s 轮询 |
| 睡眠唤醒 | `NSWorkspace.didWakeNotification` 立即刷新一次 |
| 网络恢复 | `NWPathMonitor` 从不可达变可达时立即刷新 |
| 手动刷新 | ⌘R 或点击刷新按钮 |
| 偏好设置变更 | `NotificationCenter.minimaxPreferencesDidChange` 刷新 |

---

## 八、菜单栏渲染规则

| 条件 | 菜单栏显示 |
|------|------------|
| `setupReason != nil` | ` ○`（待连接）|
| `lastError != nil && primaryModel == nil` | ` ⚠︎`（获取失败）|
| `isLoading` | `↻` 或 `⟳`（交替动画）|
| 正常 | `🟢/🟡/🔴 + tag + percent%` + `~`（缓存）+ `⬆`（有更新）|
| 有可用更新 | 附加 `· 可更新 vX.X.X` |

**颜色规则**: 剩余 >30% 绿色，>10% 黄色，≤10% 红色

---

## 九、数据层

### 9.1 API 请求

```swift
// MiniMaxAPIService.swift
GET https://api.minimaxi.com/v1/api/openplatform/coding_plan/remains
Headers: Authorization: Bearer <Token>
Timeout: 30s（可配置）
Request-ID: {timestamp}-{UUID}（可选）
```

### 9.2 三级缓存

```
内存 (QuotaState.models)
    ↓ 持久化
UserDefaults (PersistedModelQuota via QuotaStatePersistence)
    ↓ 历史记录
SQLite (UsageHistorySQLiteStore)
```

### 9.3 校验和机制

`CacheConsistencyChecker` 在 DEBUG 模式下每次成功拉取后校验数据一致性，发现异常打印诊断信息（不阻断），确保缓存不被意外污染。

---

## 十、状态与数据

| 数据 | 存储位置 | 访问方式 |
|------|----------|----------|
| 配额数据 | 内存 + UserDefaults | `QuotaState`（单一数据源） |
| 用量历史 | SQLite | `UsageHistorySQLiteStore` |
| 用户偏好 | UserDefaults | `AppStorage` / 直接读写 |
| API Key | 内存（不持久化）| `APIKeyService` |

---

## 十一、样式与界面

| 样式 | 技术 | 说明 |
|------|------|------|
| 窗口效果 | `NSVisualEffectView` | 玻璃模糊背景 |
| 按钮样式 | 自定义 `ButtonStyleApplier` | hover 高亮 |
| 卡片样式 | `CardStyleApplier` | 半透明背景 |
| 骨架屏 | `SkeletonRowView` | LinearGradient 滑动遮罩动画 |
| 菜单栏图标 | Template Image | 系统自动适配深浅色 |

---

## 十二、测试规范

### 测试框架

- **XCTest**（Apple 原生）

### 测试文件组织

| 测试文件 | 覆盖内容 |
|----------|----------|
| `APIKeyResolverTests.swift` | 环境变量解析、.env 解析、.json 解析、格式校验 |
| `APIServiceProtocolTests.swift` | Mock 返回模型、错误传播 |
| `CacheConsistencyCheckerTests.swift` | 校验和、不变量、实质性一致 |
| `DisplayModeTests.swift` | 枚举 rawValue、数字格式化 |
| `ExportServiceTests.swift` | CSV 生成、逗号转义、排序、写入 |
| `MiniMaxAPIServiceTests.swift` | URLProtocol Mock：网络错误、HTTP 错误、解码失败、API 错误 |
| `NetworkMonitorTests.swift` | 初始路径、恢复触发、持续不可达 |
| `NotificationServiceTests.swift` | 三段区间通知状态机 |
| `QuotaStatePersistenceTests.swift` | 缓存加载、持久化保存 |
| `UpdateServiceTests.swift` | 版本比较（等于/大于/不同位数）|
| `UsageRecordTests.swift` | Codable、聚合计算、日期格式化 |
| `ModelQuotaTests.swift` | Raw→Model 转换、百分比、主力模型选取 |

### Mock 策略

```swift
// 网络层 Mock
class MockURLProtocol: URLProtocol { ... }

// 持久化 Mock
class MockQuotaPersistence: QuotaStatePersistence { ... }

// API 层 Mock
class MockQuotaAPIService: APIServiceProtocol { ... }
```

### 运行测试

```bash
# Xcode 中 Cmd+U
# 或命令行
xcodebuild test -scheme minimax-status-bar -destination 'platform=macOS'
```

---

## 十三、常见坑

### 1. API JSON 字段语义

> `current_interval_usage_count` = 本周期已用次数，`current_weekly_usage_count` = 本周已用次数。剩余次数由 `total − usage` 推算。

历史代码曾反转过语义，现已修正，字段名即含义。

### 2. 主力模型选取优先级

```
M2.7 > minimax-m > 数组第一个（兜底）
```

只有主力模型触发低配额通知，新增模型时注意优先级逻辑。

### 3. 百分比边界处理

- `remainingCount > 0 && rawPercent >= 100` → 显示 99%（而非 100）
- `remainingCount == 0` → 显示 0%
- 已用不足 1% 但有消耗时 → 至少显示 1%

### 4. 歌词创作模型特殊处理

`lyrics_generation` 显示原模型名称，不使用 `Mu·` 缩写。

### 5. 网络恢复 vs 睡眠唤醒

两者**互补**而非重复：
- 网络恢复监听 `NWPathMonitor`
- 睡眠唤醒监听 `NSWorkspace.didWakeNotification`

### 6. 脏数据检测

DEBUG 模式下每次成功拉取后 `CacheConsistencyChecker` 会检查与缓存的一致性，发现异常只打印诊断信息不阻断。上线后注意观察日志。

---

## 十四、CI/CD 构建流程

```bash
# .github/workflows/release.yml
push tag v* →
  macos-15 runner →
    brew install xcodegen →
    xcodegen generate →
    xcodebuild archive →
    exportArchive →
    ad-hoc 签名 →
    hdiutil create DMG →
    softprops/action-gh-release 上传
```

---

## 十五、如何新增功能

### 新增 API 接口

1. 在 `APIServiceProtocol.swift` 添加方法签名
2. 在 `MiniMaxAPIService.swift` 实现
3. 在测试中用 `MockURLProtocol` Mock 响应

### 新增菜单栏显示模式

1. 在 `AppConfig.swift` 的 `MenuBarDisplayMode` 枚举添加选项
2. 在 `StatusBarController.updateStatusBarColor()` 添加渲染分支
3. 在 `SettingsView.swift` 添加对应的设置项

### 新增用量历史维度

1. 在 `UsageRecord.swift` 添加聚合结构（如 `QuarterlyAggregation`）
2. 在 `UsageHistorySQLiteStore.swift` 添加 upsert 查询
3. 在 `UsageHistoryRecorder.swift` 添加记录触发逻辑
4. 在 `UsageHistoryPanelView.swift` 添加展示

### 新增通知类型

1. 在 `NotificationService.swift` 添加 `UNNotificationCategory` 注册
2. 在 `AppDelegate.swift` 添加对应的 `userNotificationCenter` 处理分支

---

## 十六、关键文件索引

| 文件 | 行数 | 重要性 | 说明 |
|------|------|--------|------|
| `Sources/App/main.swift` | 18 | ⭐⭐⭐ | 入口，单实例检查 |
| `Sources/UI/StatusBarController.swift` | ~250+ | ⭐⭐⭐ | 核心编排器，Timer/轮询/刷新 |
| `Sources/Models/ModelQuota.swift` | ~250+ | ⭐⭐⭐ | 核心模型，API Raw 结构 |
| `Sources/Models/QuotaState.swift` | ~150+ | ⭐⭐⭐ | 单一数据源 |
| `Sources/Services/MiniMaxAPIService.swift` | ~150+ | ⭐⭐⭐ | API 实现 |
| `Sources/UI/DetailView.swift` | ~200+ | ⭐⭐ | 主面板容器 |
| `Sources/Services/APIKeyResolver.swift` | ~100+ | ⭐⭐ | Key 三级解析 |
| `Sources/Services/NotificationService.swift` | ~100+ | ⭐⭐ | 三段通知状态机 |
| `Sources/Services/CacheConsistencyChecker.swift` | ~100+ | ⭐⭐ | 校验和检查 |
| `Sources/UI/Settings/SettingsView.swift` | ~200+ | ⭐⭐ | 设置窗口 |
| `Tests/MiniMaxAPIServiceTests.swift` | ~100+ | ⭐⭐ | API 测试 |

---

## 十七、相关文档

| 文档 | 位置 | 内容 |
|------|------|------|
| README.md | 根目录 | 项目介绍、快速上手 |
| improvement-design.md | docs/ | v2.1.1 全面优化设计 |
| optimization-summary.md | docs/ | v2.1.2 优化总结 |
| verification-report.md | docs/ | v2.1.2 功能验证报告 |
| 2026-04-12-usage-history-plan.md | docs/superpowers/plans/ | 用量历史开发计划 |
| 2026-04-12-usage-history-design.md | docs/superpowers/specs/ | 用量历史设计规格 |
