# MiniMax Status Bar 功能增强设计文档

**版本**: v2.1.0  
**日期**: 2026-04-12  
**状态**: 已确认

## 1. 概述

本文档描述 MiniMax Status Bar v2.1.0 的功能增强方案，在不增加依赖复杂度的前提下，为用户提供用量历史统计功能和网络状态感知能力。

### 1.1 增强目标

- **用量历史**：支持按日、周、月、年查看用量趋势
- **网络感知**：网络恢复时自动刷新配额
- **极简优先**：零新依赖，符合项目核心理念

### 1.2 核心设计原则

- **YAGNI**：按需实现，不过度设计
- **零打扰**：功能增强不影响核心体验
- **极简依赖**：仅使用系统原生框架

---

## 2. 用量历史功能

### 2.1 数据存储

**方案**：UserDefaults + JSON 编码

**数据结构**：
```swift
struct DailyUsageRecord: Codable {
    let date: Date                    // 记录日期
    var modelUsages: [ModelUsage]     // 各模型用量
    let primaryModelName: String      // 当日主力模型
    let totalConsumed: Int            // 总已用量
}

struct ModelUsage: Codable {
    let modelName: String
    let consumed: Int                 // 当日已用量
    let total: Int                   // 配额上限
}
```

**存储策略**：
- 每天 API 成功返回后，记录当天各模型的已用量
- 数据保留 30 天
- 每天凌晨 4:00 清理过期数据（或启动时清理）

**数据量估算**：
- 每条记录约 200-500 字节
- 30 天总量约 15KB，极小

### 2.2 统计维度

| 维度 | 数据来源 | 说明 |
|------|---------|------|
| 日 | 当天记录 | 直接展示 |
| 周 | 最近 7 天聚合 | 7 天用量总和 + 平均 |
| 月 | 最近 4 周聚合 | 4 周用量总和（周配额 ≈ 月配额） |
| 年 | 12 个月聚合 | 12 个月用量总和 |

### 2.3 展示方式

**位置**：设置面板新增「用量历史」Tab

**界面结构**：
```
设置视图
├── TabView
│   ├── 常规设置 (原内容)
│   ├── 通知设置 (原内容)
│   ├── 用量历史 [新 Tab]
│   │   ├── 周期切换 (日 | 周 | 月 | 年)
│   │   ├── 趋势图表 (SwiftUI Charts)
│   │   └── 数据列表
│   └── 关于
```

**周期切换**：Segmented Control，默认显示「周」

**趋势图表**：
- 使用 SwiftUI Charts (macOS 13+ 原生)
- 柱状图为主
- Y 轴：已用量
- X 轴：时间周期

**数据列表**：
- 周期 | 主要模型 | 总已用 | 配额占比
- 可点击展开查看详细

### 2.4 触发时机

- API 成功返回后，记录当天用量
- 同一日期多次刷新只记录一次（以首次为准）

---

## 3. 网络状态监听

### 3.1 需求场景

- 用户网络中断后恢复，希望立即看到最新配额
- 不依赖手动刷新

### 3.2 实现方案

使用 `NWPathMonitor` 监听网络状态：

```swift
import Network

class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    
    var isConnected: Bool = true
    
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let wasConnected = self?.isConnected ?? true
            self?.isConnected = path.status == .satisfied
            
            if !wasConnected && self?.isConnected == true {
                // 网络恢复，通知刷新
                NotificationCenter.default.post(
                    name: .networkDidBecomeAvailable,
                    object: nil
                )
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
    }
}
```

### 3.3 集成点

- `StatusBarController` 监听 `networkDidBecomeAvailable`
- 网络恢复时触发一次 `manualRefresh()`
- 不影响现有的轮询 Timer

---

## 4. 文件结构

```
Sources/
├── Settings/
│   └── SettingsView.swift              # 主设置视图（含 TabView）
├── Services/
│   ├── UsageHistoryService.swift       # 用量历史数据存储/查询
│   └── NetworkMonitor.swift            # 网络状态监听
├── Models/
│   └── UsageRecord.swift               # 用量记录模型
└── UI/
    ├── DetailView.swift                # 保持不变
    └── StatusBarController.swift       # 集成网络监听

Tests/
├── UsageHistoryServiceTests.swift      # 用量历史单元测试
└── NetworkMonitorTests.swift           # 网络监听单元测试
```

---

## 5. 实施计划

### Phase 1: 基础设施
1. 创建 `UsageRecord.swift` 模型
2. 创建 `UsageHistoryService.swift` 服务
3. 创建 `NetworkMonitor.swift` 服务

### Phase 2: UI 集成
4. 创建 `SettingsView.swift` 设置面板
5. 集成用量历史 Tab
6. 集成网络监听到 `StatusBarController`

### Phase 3: 测试
7. 编写单元测试
8. 手动验证

---

## 6. 兼容性

- **最低 macOS 版本**: 13.0 (保持不变)
- **Swift 版本**: 5.9 (保持不变)
- **新增依赖**: 无

---

## 7. 验收标准

- [ ] 用量历史 Tab 显示正常
- [ ] 日/周/月/年切换正确
- [ ] 图表数据准确
- [ ] 网络恢复后自动刷新
- [ ] 单元测试全部通过
- [ ] 无编译警告
