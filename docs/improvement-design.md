# MiniMax Status Bar 全面优化设计文档

**版本**: v2.1.1（跟踪版）  
**日期**: 2026-04-12  
**状态**: 持续跟踪 — Phase 1–4 主体已落地，详见 **§7 实施跟踪**；未做项在 **§7.2**、**§8**。

---

## 1. 概述

本文档描述 MiniMax Status Bar 的全面优化方案，涵盖代码架构重构、用户体验增强、稳定性提升和功能扩展四个维度。

### 1.1 优化目标

- **代码质量**: 提升可维护性、可测试性
- **用户体验**: 更丰富的交互、更细致的视觉反馈
- **稳定性**: 更完善的错误处理、更全面的测试覆盖
- **功能**: 用量历史记录与分析

---

## 2. 代码架构重构

### 2.1 问题分析

当前 `DetailView.swift` 约 700 行，承担了过多职责：
- Header 区域渲染
- 离线缓存横幅
- 骨架屏加载
- 分类卡片列表
- 底部操作栏
- 关于面板
- Skeleton/Model Row 组件

### 2.2 重构方案

#### 2.2.1 文件拆分

| 原文件 | 新文件 | 职责 |
|--------|--------|------|
| `DetailView.swift` | `DetailView.swift` | 主容器，组装子组件 |
| - | `HeaderBarView.swift` | 标题栏、刷新按钮、About 切换 |
| - | `OfflineBannerView.swift` | 离线缓存状态横幅 |
| - | `CategoryCardView.swift` | 分类卡片（Text/Speech/Video 等） |
| - | `ModelRowView.swift` | 单个模型的行展示（已有，保留） |
| - | `BottomBarView.swift` | 底部操作栏（退出/更新/开机启动/控制台） |
| - | `AboutPanelView.swift` | 关于面板 |
| - | `SkeletonRowView.swift` | 骨架屏行（已有，保留） |

#### 2.2.2 Protocol 依赖注入

```swift
// 定义 Service Protocol
protocol APIServiceProtocol {
    func fetchQuota() async throws -> [ModelQuota]
}

protocol CacheServiceProtocol {
    func save(_ models: [ModelQuota])
    func load() -> [ModelQuota]?
}

// 实现类实现 Protocol
class MiniMaxAPIService: APIServiceProtocol { ... }
class UserDefaultsCacheService: CacheServiceProtocol { ... }

// 使用依赖注入
class QuotaState {
    init(apiService: APIServiceProtocol, cacheService: CacheServiceProtocol) {
        self.apiService = apiService
        self.cacheService = cacheService
    }
}
```

#### 2.2.3 统一错误类型

```swift
enum AppError: Error, LocalizedError {
    case apiError(APIServiceError)
    case cacheError(CacheError)
    case networkUnavailable
    case unknown

    var errorDescription: String? { ... }
}
```

### 2.3 预期收益

- 每个文件 < 150 行，职责单一
- Service 可独立测试（Mock）
- 新增功能不影响现有代码

---

## 3. 用户体验增强

### 3.1 菜单栏改进

#### 3.1.1 显示模式

支持两种菜单栏显示模式：

| 模式 | 格式 | 示例 |
|------|------|------|
| 简洁模式（默认） | `[emoji] [tag][percent]%` | `🟢 2.7·85%` |
| 详细模式 | `[emoji] [tag][percent]% [remaining]` | `🟢 2.7·85% 12.5K` |

用户可在设置中切换。

#### 3.1.2 刷新状态指示

| 状态 | 菜单栏显示 |
|------|------------|
| 刷新中 | 轻微脉动动画 + 百分比数字 |
| 成功 | 恢复正常颜色点 |
| 失败 | `⚠` + 上次缓存数据 |

### 3.2 设置面板

新增 SwiftUI 设置界面 (`SettingsView.swift`)：

```swift
struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval = 60
    @AppStorage("menuBarDisplayMode") private var displayMode = "concise"
    @AppStorage("lowQuotaNotification") private var lowQuotaNotification = true
    @AppStorage("lowQuotaThreshold") private var lowQuotaThreshold = 10
    
    // ... 设置项 UI
}
```

设置项：

| 设置项 | 类型 | 默认值 |
|--------|------|--------|
| 刷新间隔 | Picker (30s/60s/120s/300s) | 60s |
| 菜单栏显示模式 | Picker (简洁/详细) | 简洁 |
| 低配额通知 | Toggle | 开启 |
| 通知阈值 | Slider (5%-30%) | 10% |
| 自动更新 | Toggle | 关闭 |
| 开机启动 | Toggle | 跟随系统 |

### 3.3 首次引导增强

在 `SetupGuidanceView` 中添加：
- 快捷键提示徽章（⌘R 刷新、⌘Q 退出）
- API Key 验证状态实时反馈

### 3.4 视觉改进

- 骨架屏动画：Shimmer 效果替代静态占位
- 颜色方案适配 macOS 暗色/亮色模式
- 圆角、间距统一调整（卡片 12px、按钮 8px）

---

## 4. 稳定性提升

### 4.1 网络状态监听

监听系统网络状态变化：

```swift
import Network

class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    
    var isConnected: Bool = true
    
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
            if path.status == .satisfied {
                // 网络恢复，立即刷新
                NotificationCenter.default.post(name: .networkDidBecomeAvailable, object: nil)
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
    }
}
```

### 4.2 缓存一致性检查

```swift
class CacheConsistencyChecker {
    func validate(_ models: [ModelQuota], against cached: [ModelQuota]) -> CacheValidationResult {
        // 检查模型列表是否一致
        // 检查数据合理性（remaining <= total）
        // 返回警告或错误
    }
}
```

### 4.3 单元测试增强

新增测试覆盖：

| 测试文件 | 测试用例 | 数量 |
|----------|----------|------|
| `APIServiceTests.swift` | Mock URLProtocol 响应、网络错误、超时 | 8 |
| `CacheServiceTests.swift` | 序列化/反序列化、过期处理 | 5 |
| `NetworkMonitorTests.swift` | 连接/断开状态切换 | 3 |
| `DisplayModeTests.swift` | 格式化输出验证 | 4 |
| **合计** | - | **20** |

### 4.4 健壮性改进

- API 请求增加请求 ID（便于排查问题）
- 缓存数据增加校验和
- 超时时间可配置

---

## 5. 功能扩展

### 5.1 单账户说明（Token Plan Key）

> **重要说明**：MiniMax Token Plan 官方限制每个用户只能拥有一个 Token Plan Key，因此本项目不提供多账户切换与本地保存多份密钥的功能；API Key 解析仅围绕「环境变量 / OpenClaw 配置」进行。

### 5.2 用量历史

#### 5.2.1 数据存储

使用 SQLite.swift 存储历史数据：

```swift
struct QuotaHistoryRecord: Codable {
    let timestamp: Date
    let modelName: String
    let remainingCount: Int
    let totalCount: Int
    let percentRemaining: Int
}
```

#### 5.2.2 历史视图

在设置面板中添加「用量历史」Tab：

```
┌─────────────────────────────────────┐
│ [概览] [历史] [关于]                │
├─────────────────────────────────────┤
│           本周用量趋势              │
│     ▃▅█▇▅▃▂                       │
│     M  T  W  T  F  S  S            │
├─────────────────────────────────────┤
│ 日期          模型      剩余       │
│ 01-12 14:00   M2.7      85%       │
│ 01-12 13:00   M2.7      87%       │
└─────────────────────────────────────┘
```

#### 5.2.3 数据保留策略

- 保留最近 30 天数据
- 每天凌晨 3 点清理过期数据
- 数据导出支持 CSV 格式

### 5.3 数据导出

```swift
class ExportService {
    func exportToCSV(history: [QuotaHistoryRecord]) -> URL {
        // 生成 CSV 文件
        // 返回临时文件 URL
    }
}
```

导出内容包括：时间戳、模型名称、剩余次数、总额、剩余百分比。

---

## 6. 实施计划

### Phase 1: 代码架构重构
- [x] 创建 `Components/` 目录
- [x] 拆分 `DetailView` 为独立组件（Header / 离线横幅 / 分类列表 / 底栏 / 关于 / 下载遮罩；`PopoverChrome` 与平台修饰符独立文件）
- [x] 引入 `APIServiceProtocol`（`MiniMaxAPIService` 实现；`StatusBarController` 持有 `any APIServiceProtocol`）
- [x] 重构 `QuotaState` 使用依赖注入（`QuotaStatePersistence` + `UserDefaultsQuotaPersistence`，可测 Mock）
- [x] 新增 `MockQuotaAPIService` + `APIServiceProtocolTests` / `CacheConsistencyCheckerTests`

### Phase 2: 用户体验增强
- [x] 实现 `SettingsView`（通用 / 用量历史 Tab；⌘, 与标题栏齿轮打开）
- [x] 菜单栏显示模式（简洁 / 详细含剩余次数）+ 刷新中 `↻` 前缀
- [x] 骨架屏 Shimmer 动画
- [x] `SetupGuidanceView` 快捷键徽章（⌘R / ⌘, / ⌘Q）

### Phase 3: 稳定性提升
- [x] 实现 `NetworkMonitor`（`NWPathMonitor`：断网恢复后触发 `manualRefresh`，与睡眠唤醒互补）
- [x] 添加 `CacheConsistencyChecker`（剩余/总额不变量；DEBUG 下打印异常）
- [x] 编写 APIService Mock 测试（`APIServiceProtocolTests`）
- [x] API 响应时间监控（`APIMetrics` + 设置页诊断区；成功/失败均记录）

### Phase 4: 功能扩展
- [x] SQLite.swift + `UsageHistorySQLiteStore`（`~/Library/Application Support/MiniMaxStatusBar/usage_history.sqlite3`）
- [x] 用量历史 Tab（Swift Charts 近 14 日 + 列表）
- [x] CSV 导出（`NSSavePanel`）

---

## 7. 实施跟踪（已做 / 未做）

本节与仓库代码同步，便于排期与验收；更新功能后请同步改本节。

### 7.1 已完成（已实现并可在工程中核对）

| 领域 | 内容 | 主要位置 |
|------|------|----------|
| UI 拆分 | `DetailView` 拆为 `Components/*`、`PopoverChrome`、`PlatformViewModifiers` | `Sources/UI/` |
| API 抽象 | `APIServiceProtocol`、`MiniMaxAPIService` 实现 | `Sources/Services/` |
| 配额状态 DI | `QuotaStatePersistence`、`UserDefaultsQuotaPersistence`、`PersistedModelQuota`；`QuotaState.init(persistence:)`、`commitSuccessfulFetch` | `Sources/Models/`、`Sources/Services/QuotaStatePersistence.swift` |
| 网络恢复 | `NetworkMonitor`（断网→联网触发刷新） | `Sources/Services/NetworkMonitor.swift` |
| 数据校验 | `CacheConsistencyChecker`；DEBUG 打印；成功拉取后不变量检查 | `Sources/Services/CacheConsistencyChecker.swift` |
| API 耗时 | `APIMetrics`；成功/失败记录；设置页「诊断」 | `Sources/Services/APIMetrics.swift`、`MiniMaxAPIService.swift`、`SettingsView` |
| 设置 | `SettingsView`（通用 / 用量历史）；`⌘,`、标题栏齿轮 | `Sources/UI/Settings/`、`AppDelegate` |
| 菜单栏 | 简洁/详细模式（`AppStorageKeys.menuBarDisplayMode`）；刷新中 `↻⟳` 交替脉动；低配额通知读 UserDefaults 阈值/恢复线 | `StatusBarController`、`NotificationService` |
| 轮询 | 用户可选 30/60/120/300s；低余量仍 `min(10, base)`；偏好变更 `minimaxPreferencesDidChange` 重建 Timer/API | `StatusBarController` |
| 骨架屏 | Shimmer 动画 | `SkeletonRowView.swift` |
| 引导 | 快捷键徽章 ⌘R / ⌘, / ⌘Q | `SetupGuidanceView.swift` |
| 用量历史 | SQLite.swift；`UsageHistorySQLiteStore`（按日 JSON）；`UsageHistoryRecorder` 在成功拉取后写入；Charts + 列表 + CSV 导出 | `UsageHistory*.swift`、`SettingsView` |
| 单测（现有） | `APIServiceProtocolTests`、`CacheConsistencyCheckerTests`、`QuotaStatePersistenceTests`、`DisplayModeTests`、`MockQuotaPersistence`；以及既有 `ModelQuota`/`APIKey`/`Update`/`Notification`/`UsageRecord` 等 | `Tests/` |

**与早期设计稿的差异（属刻意简化或替代方案）**

| 设计稿描述 | 实际实现 |
|------------|----------|
| `CacheServiceProtocol` + `QuotaState` 内聚 API | 拉取仍在 `StatusBarController`；缓存通过 `QuotaStatePersistence` 注入 |
| `QuotaHistoryRecord` 逐条时序表 | 按 **`DailyUsageRecord` JSON** 按日 `upsert` |
| 独立 `ExportService` | ~~CSV 逻辑在 `SettingsView`~~ ✅ | `ExportService` 独立类 + 9 个单元测试 |
| `NetworkMonitor` 发 `NotificationCenter` | 使用 **回调** 调 `manualRefresh()` |

### 7.2 未做 / 待增强（原设计中有、当前仓库未实现或未完全对齐）

| 优先级建议 | 项 | 说明 |
|------------|-----|------|
| 低 | ~~菜单栏刷新「脉动」~~ ✅ | 已实现 `↻` ⟳ 交替动画，0.4s 间隔，刷新成功/失败后停止 |
| 低 | ~~Setup 内 API Key 实时校验 UI~~ ✅ | 已在 `SetupGuidanceView` 增加实时格式校验（检测值 + 粘贴值，不落盘） |
| 低 | ~~全局视觉规范~~ ✅（卡片 12px / 按钮 8px） | 已在 `UISpec` 统一样式 token 并覆盖关键 UI 组件 |
| 中 | ~~单测（设计 §4.3 规划）~~ ✅ | 已补 `MiniMaxAPIServiceTests`（URLProtocol Mock）与 `NetworkMonitorTests` |
| 低 | **API 请求 ID、缓存校验和、可配置超时** | 超时仍为服务内固定值；无请求 ID |
| 中 | ~~用量历史保留策略~~ ✅ | 已实现保留最近 30 天 + 每天 3:00 后首次成功拉取时清理 |
| 低 | **UI 自动化测试** | 无 XCUITest |
| 低 | ~~独立 `ExportService` 类~~ ✅ | `ExportService.swift` + `ExportServiceTests.swift`（9 个用例）；`SettingsView` 调用方已迁移 |

---

## 8. 技术债务与规范类待办

| 状态 | 任务 | 说明 |
|------|------|------|
| [x] | 移除未使用的 `import` | 已完成当前仓库范围内扫描并清理可定位项 |
| [x] | 统一命名：`APIKeyResolver` → `APIKeyService`（或保留现名并补文档） | 已引入 `APIKeyService` 统一入口；`APIKeyResolver` 作为兼容实现保留 |
| [x] | 公开 API 文档注释 | 已补 `StatusBarController`、`MiniMaxAPIService`、Store 层关键注释 |
| [x] | Build Warning 清理 | 已清理项目内可控 warning（含并发上下文调用告警） |
| [x] | `MiniMaxAPIService` `Sendable` / `final` 等与并发模型一致 | `final` 已落实；并发上下文相关告警已处理 |

---

## 9. 兼容性说明

- **最低 macOS 版本**: 保持 13.0
- **Swift 版本**: 保持 5.9
- **Xcode**: 推荐 15.0+

---

## 10. 测试策略

### 10.1 单元测试
- Service 层 100% 覆盖
- Model 层边界条件测试

### 10.2 集成测试
- API 响应解析
- 缓存读写一致性

### 10.3 UI 测试
- 菜单栏下拉显示
- 设置面板交互

### 10.4 当前仓库已存在的测试文件（事实清单）

| 文件 | 用途 |
|------|------|
| `APIKeyResolverTests.swift` | 密钥解析与格式 |
| `APIServiceProtocolTests.swift` | Mock `APIServiceProtocol` |
| `CacheConsistencyCheckerTests.swift` | 配额不变量 |
| `DisplayModeTests.swift` | 菜单栏模式枚举与数字格式化 |
| `ModelQuotaTests.swift` | `ModelQuota` / `QuotaState` 主模型选择 |
| `MockQuotaPersistence.swift` | 持久化 Mock（测试共享） |
| `NotificationServiceTests.swift` | 低配额通知状态机 |
| `QuotaStatePersistenceTests.swift` | `QuotaState` + 注入 |
| `UpdateServiceTests.swift` | 版本比较 |
| `UsageRecordTests.swift` | 日/周/月聚合与 Codable |
| `MiniMaxAPIServiceTests.swift` | URLProtocol Mock：网络错误 / HTTP / 解码 / 业务错误 |
| `NetworkMonitorTests.swift` | 网络恢复触发状态机 |

> 设计 §4.3 中的 `NetworkMonitorTests` 与 URLProtocol 类 API 测试已补齐；`CacheServiceTests`（若单独抽象）可在后续按需补充。

---

## 11. 发布计划

| 版本 | 内容 | 预期时间 |
|------|------|----------|
| v2.1.x | Phase 1–4 主体（见 §7.1），以及本轮已完成的稳定性/测试补齐 | 已合入主线开发 |
| v2.1.2 | 低风险体验收尾：全局视觉规范走查（卡片/按钮间距统一）、Setup 细节 polish | ✅ 已完成（2026-04-13） |
| v2.2.0 | 稳定性增强：API 请求 ID（全环境）、缓存校验和、超时配置项完善与文档化 | 中期（2–3 个迭代） |
| v2.2.x | 质量保障：UI 自动化测试（关键路径 XCUITest）与回归基线建设 | 中期（并行推进） |

---

## 附录

### A. 文件变更清单

```
新增文件:
  Sources/UI/Components/HeaderBarView.swift
  Sources/UI/Components/OfflineBannerView.swift
  Sources/UI/Components/CategoryCardListView.swift（及 LastUpdated / About / Downloading 等组件）
  Sources/UI/Components/BottomBarView.swift
  Sources/UI/Components/AboutPanelView.swift
  Sources/Services/APIServiceProtocol.swift
  Sources/Services/CacheConsistencyChecker.swift
  Sources/Services/NetworkMonitor.swift（已落地）
  Sources/UI/Settings/SettingsView.swift
  Sources/Services/APIMetrics.swift
  Sources/Services/QuotaStatePersistence.swift
  Sources/Services/UsageHistorySQLiteStore.swift
  Sources/Services/UsageHistoryRecorder.swift
  Sources/Models/PersistedModelQuota.swift
  Tests/APIServiceProtocolTests.swift
  Tests/CacheConsistencyCheckerTests.swift
  Tests/DisplayModeTests.swift
  Tests/QuotaStatePersistenceTests.swift
  Tests/MockQuotaPersistence.swift
  （另有既有：APIKeyResolver / ModelQuota / Notification / Update / UsageRecord 等测试）

修改文件（非穷举）:
  Sources/UI/DetailView.swift
  Sources/UI/StatusBarController.swift
  Sources/UI/MenuContentView.swift
  Sources/Models/QuotaState.swift
  Sources/Models/ModelQuota.swift
  Sources/Services/MiniMaxAPIService.swift
  Sources/Services/NotificationService.swift
  Sources/App/AppDelegate.swift
  Sources/Config/AppConfig.swift
  project.yml
  docs/improvement-design.md

删除文件:
  (无)
```

### B. 依赖变更

新增依赖:
- `SQLite.swift`（XcodeGen: `SQLiteSwift` 包，product `SQLite`）— 用量历史按日 JSON 存储
