# MiniMax Status Bar 功能增强实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 MiniMax Status Bar 添加用量历史统计（按日/周/月/年）和网络状态自动刷新功能

**Architecture:** 使用 UserDefaults 存储每日用量记录，SQLite-free 设计；使用 NWPathMonitor 监听网络状态；SwiftUI Charts 展示趋势图

**Tech Stack:** Swift 5.9, SwiftUI Charts (macOS 13+), UserDefaults, NWPathMonitor

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `Sources/Models/UsageRecord.swift` | 用量记录数据模型 |
| `Sources/Services/UsageHistoryService.swift` | 用量历史存储与查询服务 |
| `Sources/Services/NetworkMonitor.swift` | 网络状态监听服务 |
| `Sources/UI/SettingsView.swift` | 设置面板（含用量历史 Tab） |
| `Sources/UI/DetailView.swift` | 集成设置入口 |
| `Sources/UI/StatusBarController.swift` | 集成网络监听 |
| `Tests/UsageHistoryServiceTests.swift` | 用量历史单元测试 |

---

## Task 1: 创建用量记录模型

**Files:**
- Create: `Sources/Models/UsageRecord.swift`
- Test: `Tests/UsageRecordTests.swift`

- [ ] **Step 1: 创建测试文件并写入测试**

```swift
import XCTest
@testable import MiniMax_Status_Bar

final class UsageRecordTests: XCTestCase {
    func testDailyUsageRecordCodable() throws {
        let record = DailyUsageRecord(
            date: Date(),
            modelUsages: [
                ModelUsage(modelName: "MiniMax-M2.7", consumed: 5000, total: 10000),
                ModelUsage(modelName: "hailuo-video", consumed: 100, total: 1000)
            ],
            primaryModelName: "MiniMax-M2.7",
            totalConsumed: 5100
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(record)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DailyUsageRecord.self, from: data)
        
        XCTAssertEqual(decoded.primaryModelName, "MiniMax-M2.7")
        XCTAssertEqual(decoded.totalConsumed, 5100)
        XCTAssertEqual(decoded.modelUsages.count, 2)
    }
    
    func testModelUsageCalculation() {
        let usage = ModelUsage(modelName: "MiniMax-M2.7", consumed: 2500, total: 10000)
        XCTAssertEqual(usage.consumedPercent, 25)
        XCTAssertEqual(usage.remaining, 7500)
    }
    
    func testWeeklyAggregation() throws {
        let records = try createWeeklyRecords()
        let aggregated = WeeklyAggregation.aggregate(from: records)
        
        XCTAssertEqual(aggregated.weekStartDate.weekday, 2) // Monday
        XCTAssertEqual(aggregated.totalConsumed, 35000)
        XCTAssertEqual(aggregated.primaryModelName, "MiniMax-M2.7")
    }
    
    func testMonthlyAggregation() throws {
        let records = try createMonthRecords()
        let aggregated = MonthlyAggregation.aggregate(from: records)
        
        XCTAssertEqual(aggregated.yearMonth, "2026-04")
        XCTAssertEqual(aggregated.totalConsumed, 150000)
    }
    
    private func createWeeklyRecords() throws -> [DailyUsageRecord] {
        let calendar = Calendar.current
        let today = Date()
        var records: [DailyUsageRecord] = []
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                throw NSError(domain: "Test", code: 0)
            }
            let record = DailyUsageRecord(
                date: date,
                modelUsages: [ModelUsage(modelName: "MiniMax-M2.7", consumed: 5000, total: 10000)],
                primaryModelName: "MiniMax-M2.7",
                totalConsumed: 5000
            )
            records.append(record)
        }
        return records
    }
    
    private func createMonthRecords() throws -> [DailyUsageRecord] {
        let calendar = Calendar.current
        let today = Date()
        var records: [DailyUsageRecord] = []
        
        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                throw NSError(domain: "Test", code: 0)
            }
            let record = DailyUsageRecord(
                date: date,
                modelUsages: [ModelUsage(modelName: "MiniMax-M2.7", consumed: 5000, total: 10000)],
                primaryModelName: "MiniMax-M2.7",
                totalConsumed: 5000
            )
            records.append(record)
        }
        return records
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd /Users/victor/Documents/new\ workspace/minimax-status-bar && xcodebuild test -scheme minimax-status-bar -destination 'platform=macOS' -only-testing:minimax_status_barTests/UsageRecordTests 2>&1 | grep -E "(FAIL|error:)"`

Expected: `error: no such module 'MiniMax_Status_Bar'` 或测试文件未找到

- [ ] **Step 3: 创建 UsageRecord.swift 实现**

```swift
import Foundation

/// 单个模型的用量统计
struct ModelUsage: Codable, Identifiable {
    var id: String { modelName }
    let modelName: String
    /// 当日/周期已消耗量
    let consumed: Int
    /// 配额上限
    let total: Int
    
    /// 已用百分比 (0-100)
    var consumedPercent: Int {
        guard total > 0 else { return 0 }
        return consumed * 100 / total
    }
    
    /// 剩余量
    var remaining: Int {
        max(0, total - consumed)
    }
}

/// 每日用量记录
struct DailyUsageRecord: Codable, Identifiable {
    var id: String { dateKey }
    /// 记录日期（只含日期，不含时间）
    let date: Date
    /// 各模型用量列表
    var modelUsages: [ModelUsage]
    /// 当日主力模型名称
    let primaryModelName: String
    /// 总已消耗量
    let totalConsumed: Int
    
    /// 日期字符串键，格式 "yyyy-MM-dd"
    var dateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    /// 格式化日期显示
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
    
    /// 主力模型已用量
    var primaryModelConsumed: Int {
        modelUsages.first { $0.modelName == primaryModelName }?.consumed ?? 0
    }
}

/// 周聚合数据
struct WeeklyAggregation: Identifiable {
    var id: String { weekKey }
    /// 周起始日期
    let weekStartDate: Date
    /// 周结束日期
    let weekEndDate: Date
    /// 周键，格式 "yyyy-'W'ww"
    var weekKey: String
    /// 总已消耗量
    let totalConsumed: Int
    /// 主力模型名称
    let primaryModelName: String
    /// 主力模型已消耗量
    let primaryModelConsumed: Int
    /// 该周记录天数
    let recordCount: Int
    
    /// 日均消耗
    var dailyAverage: Int {
        guard recordCount > 0 else { return 0 }
        return totalConsumed / recordCount
    }
    
    /// 周标签显示
    var weekLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return "\(formatter.string(from: weekStartDate))-\(formatter.string(from: weekEndDate))"
    }
    
    /// 从日记录聚合
    static func aggregate(from records: [DailyUsageRecord]) -> WeeklyAggregation? {
        guard !records.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let sortedRecords = records.sorted { $0.date < $1.date }
        
        guard let firstDate = sortedRecords.first?.date,
              let lastDate = sortedRecords.last?.date,
              let weekStart = calendar.dateInterval(of: .weekOfYear, for: firstDate)?.start,
              let weekEnd = calendar.dateInterval(of: .weekOfYear, for: lastDate)?.end else {
            return nil
        }
        
        // 计算该周所有记录的总量
        let totalConsumed = sortedRecords.reduce(0) { $0 + $1.totalConsumed }
        
        // 找出主力模型（消耗最多的）
        var modelTotals: [String: Int] = [:]
        for record in sortedRecords {
            for usage in record.modelUsages {
                modelTotals[usage.modelName, default: 0] += usage.consumed
            }
        }
        let primaryModel = modelTotals.max { $0.value < $1.value }?.key ?? ""
        let primaryConsumed = modelTotals[primaryModel] ?? 0
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-'W'ww"
        let weekKey = formatter.string(from: weekStart)
        
        return WeeklyAggregation(
            weekStartDate: weekStart,
            weekEndDate: calendar.date(byAdding: .day, value: -1, to: weekEnd) ?? weekEnd,
            weekKey: weekKey,
            totalConsumed: totalConsumed,
            primaryModelName: primaryModel,
            primaryModelConsumed: primaryConsumed,
            recordCount: sortedRecords.count
        )
    }
}

/// 月聚合数据
struct MonthlyAggregation: Identifiable {
    var id: String { yearMonth }
    /// 年月，格式 "yyyy-MM"
    let yearMonth: String
    /// 月份名称
    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        if let date = formatter.date(from: yearMonth) {
            formatter.dateFormat = "yyyy年M月"
            return formatter.string(from: date)
        }
        return yearMonth
    }
    /// 总已消耗量
    let totalConsumed: Int
    /// 主力模型名称
    let primaryModelName: String
    /// 主力模型已消耗量
    let primaryModelConsumed: Int
    /// 该月记录天数
    let recordCount: Int
    
    /// 日均消耗
    var dailyAverage: Int {
        guard recordCount > 0 else { return 0 }
        return totalConsumed / recordCount
    }
    
    /// 从日记录聚合
    static func aggregate(from records: [DailyUsageRecord]) -> MonthlyAggregation? {
        guard !records.isEmpty else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        
        // 按月分组
        let monthKey = formatter.string(from: records[0].date)
        let monthRecords = records.filter { formatter.string(from: $0.date) == monthKey }
        
        let totalConsumed = monthRecords.reduce(0) { $0 + $1.totalConsumed }
        
        // 找出主力模型
        var modelTotals: [String: Int] = [:]
        for record in monthRecords {
            for usage in record.modelUsages {
                modelTotals[usage.modelName, default: 0] += usage.consumed
            }
        }
        let primaryModel = modelTotals.max { $0.value < $1.value }?.key ?? ""
        let primaryConsumed = modelTotals[primaryModel] ?? 0
        
        return MonthlyAggregation(
            yearMonth: monthKey,
            totalConsumed: totalConsumed,
            primaryModelName: primaryModel,
            primaryModelConsumed: primaryConsumed,
            recordCount: monthRecords.count
        )
    }
}

/// 年聚合数据
struct YearlyAggregation: Identifiable {
    var id: String { year }
    /// 年份
    let year: String
    /// 总已消耗量
    let totalConsumed: Int
    /// 主力模型名称
    let primaryModelName: String
    /// 主力模型已消耗量
    let primaryModelConsumed: Int
    /// 该年记录月数
    let recordCount: Int
    
    /// 月均消耗
    var monthlyAverage: Int {
        guard recordCount > 0 else { return 0 }
        return totalConsumed / recordCount
    }
    
    /// 从月聚合聚合
    static func aggregate(from monthlies: [MonthlyAggregation]) -> YearlyAggregation? {
        guard !monthlies.isEmpty else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        
        let year = String(monthlies[0].yearMonth.prefix(4))
        let totalConsumed = monthlies.reduce(0) { $0 + $1.totalConsumed }
        
        var modelTotals: [String: Int] = [:]
        for monthly in monthlies {
            modelTotals[monthly.primaryModelName, default: 0] += monthly.primaryModelConsumed
        }
        let primaryModel = modelTotals.max { $0.value < $1.value }?.key ?? ""
        let primaryConsumed = modelTotals[primaryModel] ?? 0
        
        return YearlyAggregation(
            year: year,
            totalConsumed: totalConsumed,
            primaryModelName: primaryModel,
            primaryModelConsumed: primaryConsumed,
            recordCount: monthlies.count
        )
    }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd /Users/victor/Documents/new\ workspace/minimax-status-bar && xcodebuild test -scheme minimax-status-bar -destination 'platform=macOS' -only-testing:minimax_status_barTests/UsageRecordTests 2>&1 | grep -E "(passed|failed)"`

Expected: 4 tests passed

- [ ] **Step 5: 提交**

```bash
cd /Users/victor/Documents/new\ workspace/minimax-status-bar
git add Sources/Models/UsageRecord.swift Tests/UsageRecordTests.swift
git commit -m "feat: add UsageRecord model for daily/weekly/monthly/yearly aggregations"
```

---

## Task 2: 创建用量历史服务

**Files:**
- Create: `Sources/Services/UsageHistoryService.swift`
- Test: `Tests/UsageHistoryServiceTests.swift`

- [ ] **Step 1: 创建测试文件并写入测试**

```swift
import XCTest
@testable import MiniMax_Status_Bar

final class UsageHistoryServiceTests: XCTestCase {
    var service: UsageHistoryService!
    let testKey = "TestUsageHistory"
    
    override func setUp() {
        super.setUp()
        // 使用测试专用的 key
        service = UsageHistoryService(storageKey: testKey)
        // 清理测试数据
        UserDefaults.standard.removeObject(forKey: testKey)
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: testKey)
        service = nil
        super.tearDown()
    }
    
    func testRecordDailyUsage() {
        let models = [
            ModelQuota.from(raw: ModelQuotaRaw(
                modelName: "MiniMax-M2.7",
                currentIntervalTotalCount: 10000,
                currentIntervalRemainingCount: 5000,
                currentWeeklyTotalCount: 40000,
                currentWeeklyRemainingCount: 20000,
                remainsTime: 86400000,
                weeklyStartTime: 0,
                weeklyEndTime: 604800000
            ))
        ]
        
        service.recordDailyUsage(from: models)
        
        let records = service.getAllRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].totalConsumed, 5000)
    }
    
    func testPreventsDuplicateRecording() {
        let models = [
            ModelQuota.from(raw: ModelQuotaRaw(
                modelName: "MiniMax-M2.7",
                currentIntervalTotalCount: 10000,
                currentIntervalRemainingCount: 8000,
                currentWeeklyTotalCount: 40000,
                currentWeeklyRemainingCount: 30000,
                remainsTime: 86400000,
                weeklyStartTime: 0,
                weeklyEndTime: 604800000
            ))
        ]
        
        service.recordDailyUsage(from: models)
        service.recordDailyUsage(from: models) // 同一日期再次记录
        
        let records = service.getAllRecords()
        XCTAssertEqual(records.count, 1) // 仍然是 1 条
    }
    
    func testCleanupOldRecords() {
        // 创建 35 天前的假数据
        let oldDate = Calendar.current.date(byAdding: .day, value: -35, to: Date())!
        let oldRecord = DailyUsageRecord(
            date: oldDate,
            modelUsages: [ModelUsage(modelName: "test", consumed: 100, total: 1000)],
            primaryModelName: "test",
            totalConsumed: 100
        )
        
        // 手动写入旧数据
        var records = service.getAllRecords()
        records.append(oldRecord)
        service.saveRecords(records)
        
        // 清理
        service.cleanupOldRecords()
        
        let remaining = service.getAllRecords()
        XCTAssertEqual(remaining.count, 0) // 旧数据应被清理
    }
    
    func testGetWeeklyAggregations() {
        // 创建过去 14 天的假数据
        let calendar = Calendar.current
        var records: [DailyUsageRecord] = []
        
        for dayOffset in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let record = DailyUsageRecord(
                date: date,
                modelUsages: [ModelUsage(modelName: "MiniMax-M2.7", consumed: 1000, total: 10000)],
                primaryModelName: "MiniMax-M2.7",
                totalConsumed: 1000
            )
            records.append(record)
        }
        service.saveRecords(records)
        
        let weeklies = service.getWeeklyAggregations()
        
        // 14 天应该跨 2 周
        XCTAssertTrue(weeklies.count >= 1)
        if let thisWeek = weeklies.first {
            XCTAssertEqual(thisWeek.totalConsumed, 7000) // 最近 7 天
        }
    }
    
    func testGetMonthlyAggregations() {
        // 创建过去 60 天的假数据
        let calendar = Calendar.current
        var records: [DailyUsageRecord] = []
        
        for dayOffset in 0..<60 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let record = DailyUsageRecord(
                date: date,
                modelUsages: [ModelUsage(modelName: "MiniMax-M2.7", consumed: 1000, total: 10000)],
                primaryModelName: "MiniMax-M2.7",
                totalConsumed: 1000
            )
            records.append(record)
        }
        service.saveRecords(records)
        
        let monthlies = service.getMonthlyAggregations()
        
        // 应该至少有本月数据
        XCTAssertTrue(!monthlies.isEmpty)
    }
    
    func testGetYearlyAggregations() {
        // 创建过去 400 天的假数据
        let calendar = Calendar.current
        var records: [DailyUsageRecord] = []
        
        for dayOffset in 0..<400 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let record = DailyUsageRecord(
                date: date,
                modelUsages: [ModelUsage(modelName: "MiniMax-M2.7", consumed: 1000, total: 10000)],
                primaryModelName: "MiniMax-M2.7",
                totalConsumed: 1000
            )
            records.append(record)
        }
        service.saveRecords(records)
        
        let yearlies = service.getYearlyAggregations()
        
        // 400 天可能跨 1-2 年
        XCTAssertTrue(!yearlies.isEmpty)
    }
    
    func testGetRecentRecords() {
        // 创建 30 天的假数据
        let calendar = Calendar.current
        var records: [DailyUsageRecord] = []
        
        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let record = DailyUsageRecord(
                date: date,
                modelUsages: [ModelUsage(modelName: "MiniMax-M2.7", consumed: 1000, total: 10000)],
                primaryModelName: "MiniMax-M2.7",
                totalConsumed: 1000
            )
            records.append(record)
        }
        service.saveRecords(records)
        
        let recent = service.getRecentRecords(days: 7)
        
        // 最近的 7 天（可能包含今天）
        XCTAssertTrue(recent.count <= 7)
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd /Users/victor/Documents/new\ workspace/minimax-status-bar && xcodebuild test -scheme minimax-status-bar -destination 'platform=macOS' -only-testing:minimax_status_barTests/UsageHistoryServiceTests 2>&1 | grep -E "(FAIL|error:|UsageHistoryServiceTests)"`

Expected: 测试编译失败或 `error: cannot find type 'UsageHistoryService'`

- [ ] **Step 3: 创建 UsageHistoryService.swift 实现**

```swift
import Foundation

/// 用量历史服务 - 负责数据的存储、查询和清理
final class UsageHistoryService {
    /// UserDefaults 存储键
    private let storageKey: String
    /// 数据保留天数
    private let retentionDays: Int
    
    /// 编码器
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    /// 解码器
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    init(storageKey: String = "UsageHistoryRecords", retentionDays: Int = 30) {
        self.storageKey = storageKey
        self.retentionDays = retentionDays
    }
    
    // MARK: - 记录
    
    /// 记录当日用量（从 ModelQuota 数组计算）
    /// - Parameter models: 当前配额状态
    func recordDailyUsage(from models: [ModelQuota]) {
        guard !models.isEmpty else { return }
        
        // 获取今天的日期（只含日期部分）
        let today = Calendar.current.startOfDay(for: Date())
        let todayKey = dateKey(for: today)
        
        // 检查今天是否已有记录
        var records = getAllRecords()
        if records.contains(where: { $0.dateKey == todayKey }) {
            // 今天已记录，跳过
            return
        }
        
        // 计算各模型已用量
        let modelUsages = models.map { model in
            ModelUsage(
                modelName: model.modelName,
                consumed: model.intervalConsumedCount,
                total: model.totalCount
            )
        }
        
        // 找出主力模型（剩余百分比最低的）
        let primaryModel = models.min { $0.remainingPercent < $1.remainingPercent }
        
        // 计算总已用量
        let totalConsumed = models.reduce(0) { $0 + $1.intervalConsumedCount }
        
        let record = DailyUsageRecord(
            date: today,
            modelUsages: modelUsages,
            primaryModelName: primaryModel?.modelName ?? "",
            totalConsumed: totalConsumed
        )
        
        records.append(record)
        saveRecords(records)
        
        // 清理过期数据
        cleanupOldRecords()
    }
    
    // MARK: - 查询
    
    /// 获取所有记录
    func getAllRecords() -> [DailyUsageRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        
        do {
            let records = try decoder.decode([DailyUsageRecord].self, from: data)
            return records.sorted { $0.date < $1.date }
        } catch {
            print("[UsageHistoryService] Failed to decode records: \(error)")
            return []
        }
    }
    
    /// 获取最近 N 天的记录
    func getRecentRecords(days: Int) -> [DailyUsageRecord] {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return getAllRecords().filter { $0.date >= cutoffDate }
    }
    
    /// 获取周聚合数据
    func getWeeklyAggregations() -> [WeeklyAggregation] {
        let records = getRecentRecords(days: retentionDays)
        guard !records.isEmpty else { return [] }
        
        let calendar = Calendar.current
        var weeklies: [WeeklyAggregation] = []
        var currentWeekRecords: [DailyUsageRecord] = []
        var lastWeekOfYear: Int?
        
        for record in records {
            let weekOfYear = calendar.component(.weekOfYear, from: record.date)
            let year = calendar.component(.year, from: record.date)
            
            if let last = lastWeekOfYear, weekOfYear != last {
                // 周变化，聚合当前周
                if let aggregated = WeeklyAggregation.aggregate(from: currentWeekRecords) {
                    weeklies.append(aggregated)
                }
                currentWeekRecords = []
            }
            
            currentWeekRecords.append(record)
            lastWeekOfYear = weekOfYear
        }
        
        // 聚合最后一周
        if let aggregated = WeeklyAggregation.aggregate(from: currentWeekRecords) {
            weeklies.append(aggregated)
        }
        
        return weeklies.reversed() // 最新的在前面
    }
    
    /// 获取月聚合数据
    func getMonthlyAggregations() -> [MonthlyAggregation] {
        let records = getRecentRecords(days: retentionDays)
        guard !records.isEmpty else { return [] }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        
        var monthGroups: [String: [DailyUsageRecord]] = [:]
        
        for record in records {
            let key = formatter.string(from: record.date)
            monthGroups[key, default: []].append(record)
        }
        
        var monthlies: [MonthlyAggregation] = []
        
        for (_, groupRecords) in monthGroups.sorted(by: { $0.key > $1.key }) {
            if let aggregated = MonthlyAggregation.aggregate(from: groupRecords) {
                monthlies.append(aggregated)
            }
        }
        
        return monthlies.reversed() // 最新的在前面
    }
    
    /// 获取年聚合数据
    func getYearlyAggregations() -> [YearlyAggregation] {
        let monthlies = getMonthlyAggregations()
        guard !monthlies.isEmpty else { return [] }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        
        var yearGroups: [String: [MonthlyAggregation]] = [:]
        
        for monthly in monthlies {
            let year = String(monthly.yearMonth.prefix(4))
            yearGroups[year, default: []].append(monthly)
        }
        
        var yearlies: [YearlyAggregation] = []
        
        for (_, groupMonthlies) in yearGroups.sorted(by: { $0.key > $1.key }) {
            if let aggregated = YearlyAggregation.aggregate(from: groupMonthlies) {
                yearlies.append(aggregated)
            }
        }
        
        return yearlies.reversed() // 最新的在前面
    }
    
    // MARK: - 清理
    
    /// 清理过期的数据
    func cleanupOldRecords() {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        
        var records = getAllRecords()
        let originalCount = records.count
        records.removeAll { $0.date < cutoffDate }
        
        if records.count < originalCount {
            saveRecords(records)
            print("[UsageHistoryService] Cleaned up \(originalCount - records.count) old records")
        }
    }
    
    // MARK: - 私有方法
    
    /// 保存记录到 UserDefaults
    private func saveRecords(_ records: [DailyUsageRecord]) {
        do {
            let data = try encoder.encode(records)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("[UsageHistoryService] Failed to encode records: \(error)")
        }
    }
    
    /// 获取日期字符串键
    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd /Users/victor/Documents/new\ workspace/minimax-status-bar && xcodebuild test -scheme minimax-status-bar -destination 'platform=macOS' -only-testing:minimax_status_barTests/UsageHistoryServiceTests 2>&1 | grep -E "(passed|failed)"`

Expected: 7 tests passed

- [ ] **Step 5: 提交**

```bash
cd /Users/victor/Documents/new\ workspace/minimax-status-bar
git add Sources/Services/UsageHistoryService.swift Tests/UsageHistoryServiceTests.swift
git commit -m "feat: add UsageHistoryService for storing and querying usage history"
```

---

## Task 3: 创建网络状态监听服务

**Files:**
- Create: `Sources/Services/NetworkMonitor.swift`

- [ ] **Step 1: 创建 NetworkMonitor.swift 实现**

```swift
import Foundation
import Network

/// 网络状态变化通知
extension Notification.Name {
    static let networkDidBecomeAvailable = Notification.Name("networkDidBecomeAvailable")
    static let networkDidBecomeUnavailable = Notification.Name("networkDidBecomeUnavailable")
}

/// 网络状态监听服务
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.openclaw.minimax-status-bar.networkmonitor", qos: .utility)
    
    /// 当前网络连接状态
    private(set) var isConnected: Bool = true
    
    /// 是否正在监听
    private var isMonitoring: Bool = false
    
    private init() {
        monitor = NWPathMonitor()
    }
    
    /// 开始监听网络状态
    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let wasConnected = self.isConnected
            let nowConnected = path.status == .satisfied
            
            self.isConnected = nowConnected
            
            // 网络从断开变为连接
            if !wasConnected && nowConnected {
                print("[NetworkMonitor] Network became available")
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .networkDidBecomeAvailable,
                        object: nil
                    )
                }
            }
            // 网络从连接变为断开
            else if wasConnected && !nowConnected {
                print("[NetworkMonitor] Network became unavailable")
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .networkDidBecomeUnavailable,
                        object: nil
                    )
                }
            }
        }
        
        monitor.start(queue: queue)
        print("[NetworkMonitor] Started monitoring network status")
    }
    
    /// 停止监听网络状态
    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false
        monitor.cancel()
        print("[NetworkMonitor] Stopped monitoring network status")
    }
    
    deinit {
        stop()
    }
}
```

- [ ] **Step 2: 验证代码编译**

Run: `cd /Users/victor/Documents/new\ workspace/minimax-status-bar && xcodebuild build -scheme minimax-status-bar -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)" | head -5`

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 提交**

```bash
cd /Users/victor/Documents/new\ workspace/minimax-status-bar
git add Sources/Services/NetworkMonitor.swift
git commit -m "feat: add NetworkMonitor service using NWPathMonitor"
```

---

## Task 4: 集成网络监听到 StatusBarController

**Files:**
- Modify: `Sources/UI/StatusBarController.swift:1-30` (添加导入和初始化)
- Modify: `Sources/UI/StatusBarController.swift` (在 init 中启动监听)

- [ ] **Step 1: 添加 Network 导入**

在文件顶部添加：

```swift
import Network
```

- [ ] **Step 2: 在 init 中启动网络监听**

在 `init()` 方法的末尾添加：

```swift
// 启动网络状态监听
NetworkMonitor.shared.start()
```

- [ ] **Step 3: 添加网络恢复刷新逻辑**

在 `init()` 方法中，添加通知观察者：

```swift
// 监听网络恢复通知
NotificationCenter.default.addObserver(
    forName: .networkDidBecomeAvailable,
    object: nil,
    queue: .main
) { [weak self] _ in
    self?.manualRefresh()
}
```

- [ ] **Step 4: 在 deinit 中清理**

```swift
deinit {
    // ... 现有代码 ...
    // 停止网络监听
    NetworkMonitor.shared.stop()
}
```

- [ ] **Step 5: 验证编译**

Run: `cd /Users/victor/Documents/new\ workspace/minimax-status-bar && xcodebuild build -scheme minimax-status-bar -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)" | head -5`

Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: 提交**

```bash
cd /Users/victor/Documents/new\ workspace/minimax-status-bar
git add Sources/UI/StatusBarController.swift
git commit -m "feat: integrate NetworkMonitor to auto-refresh on network recovery"
```

---

## Task 5: 集成用量记录到 StatusBarController

**Files:**
- Modify: `Sources/UI/StatusBarController.swift` (API 成功后记录用量)

- [ ] **Step 1: 在 API 成功回调中记录用量**

找到 `refresh()` 方法中的成功处理：

```swift
// 在现有代码的 API 成功处理块中添加：
do {
    let models = try await api.fetchQuota()
    await MainActor.run {
        // ... 现有代码 ...
        
        // 记录用量历史
        UsageHistoryService().recordDailyUsage(from: models)
        
        // ... 现有代码 ...
    }
} catch {
```

- [ ] **Step 2: 验证编译**

Run: `cd /Users/victor/Documents/new\ workspace/minimax-status-bar && xcodebuild build -scheme minimax-status-bar -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)" | head -5`

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 提交**

```bash
cd /Users/victor/Documents/new\ workspace/minimax-status-bar
git add Sources/UI/StatusBarController.swift
git commit -m "feat: record daily usage after successful API fetch"
```

---

## Task 6: 创建设置面板视图

**Files:**
- Create: `Sources/UI/SettingsView.swift`

- [ ] **Step 1: 创建 SettingsView.swift**

```swift
import SwiftUI
import Charts

/// 设置视图 Tab
enum SettingsTab: String, CaseIterable {
    case general = "常规"
    case notifications = "通知"
    case history = "用量历史"
    case about = "关于"
}

/// 用量历史视图
struct UsageHistoryView: View {
    @StateObject private var historyService = UsageHistoryService()
    @State private var selectedPeriod: UsagePeriod = .weekly
    
    enum UsagePeriod: String, CaseIterable {
        case daily = "日"
        case weekly = "周"
        case monthly = "月"
        case yearly = "年"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 周期切换
            Picker("统计周期", selection: $selectedPeriod) {
                ForEach(UsagePeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            
            // 趋势图表
            chartView
                .frame(height: 200)
            
            Divider()
            
            // 数据列表
            dataListView
        }
        .padding()
        .onAppear {
            // 清理过期数据
            historyService.cleanupOldRecords()
        }
    }
    
    @ViewBuilder
    private var chartView: some View {
        let data = chartData
        
        if data.isEmpty {
            VStack {
                Image(systemName: "chart.bar")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(data) { item in
                BarMark(
                    x: .value("周期", item.label),
                    y: .value("已用量", item.value)
                )
                .foregroundStyle(
                    item.label.contains(Formatter.currentMonth()) 
                    ? Color.accentColor 
                    : Color.gray.opacity(0.6)
                )
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text(Formatter.formatNumber(intValue))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let strValue = value.as(String.self) {
                            Text(strValue)
                                .font(.caption2)
                        }
                    }
                }
            }
        }
    }
    
    private var chartData: [ChartDataPoint] {
        switch selectedPeriod {
        case .daily:
            return historyService.getRecentRecords(days: 7).map { record in
                ChartDataPoint(
                    label: record.formattedDate,
                    value: record.totalConsumed,
                    date: record.date
                )
            }
        case .weekly:
            return historyService.getWeeklyAggregations().prefix(8).map { weekly in
                ChartDataPoint(
                    label: weekly.weekLabel,
                    value: weekly.totalConsumed,
                    date: weekly.weekStartDate
                )
            }
        case .monthly:
            return historyService.getMonthlyAggregations().prefix(12).map { monthly in
                ChartDataPoint(
                    label: monthly.monthName,
                    value: monthly.totalConsumed,
                    date: Date()
                )
            }
        case .yearly:
            return historyService.getYearlyAggregations().prefix(5).map { yearly in
                ChartDataPoint(
                    label: yearly.year + "年",
                    value: yearly.totalConsumed,
                    date: Date()
                )
            }
        }
    }
    
    @ViewBuilder
    private var dataListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("详细数据")
                .font(.headline)
            
            if chartData.isEmpty {
                Text("暂无记录")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(chartData.reversed().prefix(10), id: \.label) { item in
                    HStack {
                        Text(item.label)
                            .font(.caption)
                            .frame(width: 80, alignment: .leading)
                        
                        Text(Formatter.formatNumber(item.value))
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("主力: MiniMax-M2.7")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    if item.label != chartData.last?.label {
                        Divider()
                    }
                }
            }
        }
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Int
    let date: Date
}

/// 格式化辅助
enum Formatter {
    static func formatNumber(_ num: Int) -> String {
        if num >= 1_000_000_000 {
            return String(format: "%.1fB", Double(num) / 1_000_000_000)
        } else if num >= 1_000_000 {
            return String(format: "%.1fM", Double(num) / 1_000_000)
        } else if num >= 1_000 {
            return String(format: "%.1fK", Double(num) / 1_000)
        }
        return "\(num)"
    }
    
    static func currentMonth() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M"
        return formatter.string(from: Date())
    }
}

/// 设置视图主容器
struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("常规", systemImage: "gear")
                }
                .tag(SettingsTab.general)
            
            NotificationSettingsView()
                .tabItem {
                    Label("通知", systemImage: "bell")
                }
                .tag(SettingsTab.notifications)
            
            UsageHistoryView()
                .tabItem {
                    Label("用量历史", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(SettingsTab.history)
            
            AboutSettingsView()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 400, height: 450)
    }
}

/// 常规设置视图
struct GeneralSettingsView: View {
    @AppStorage(AppStorageKeys.prefersAutomaticUpdateInstall) private var prefersAutomaticUpdateInstall = false
    @State private var refreshInterval: Double = 60
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("刷新间隔")
                    Spacer()
                    Picker("", selection: $refreshInterval) {
                        Text("30 秒").tag(30.0)
                        Text("1 分钟").tag(60.0)
                        Text("2 分钟").tag(120.0)
                        Text("5 分钟").tag(300.0)
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }
            } header: {
                Text("刷新")
            }
            
            Section {
                Toggle("自动更新", isOn: $prefersAutomaticUpdateInstall)
            } header: {
                Text("更新")
            } footer: {
                Text("开启后，发现新版本会自动下载并安装")
            }
        }
        .padding()
    }
}

/// 通知设置视图
struct NotificationSettingsView: View {
    @AppStorage("lowQuotaNotificationEnabled") private var lowQuotaNotificationEnabled = true
    @AppStorage("lowQuotaThreshold") private var lowQuotaThreshold: Double = 10
    
    var body: some View {
        Form {
            Section {
                Toggle("低配额通知", isOn: $lowQuotaNotificationEnabled)
            } header: {
                Text("通知")
            } footer: {
                Text("当主力模型配额低于阈值时发送通知")
            }
            
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("通知阈值")
                        Spacer()
                        Text("\(Int(lowQuotaThreshold))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $lowQuotaThreshold, in: 5...30, step: 5) {
                        Text("阈值")
                    }
                }
            } header: {
                Text("阈值")
            }
        }
        .padding()
    }
}

/// 关于设置视图
struct AboutSettingsView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if let icon = NSImage(named: "StatusBarIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
            }
            
            Text("MiniMax Status Bar")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("v\(appVersion)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            Text("为重度使用 MiniMax Token Plan 的开发者而生。菜单栏一眼感知配额，零配置，零打扰。")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Divider()
            
            VStack(spacing: 8) {
                Link(destination: URL(string: "https://platform.minimaxi.com/user-center/payment/token-plan")!) {
                    HStack {
                        Image(systemName: "link")
                        Text("MiniMax Token Plan 控制台")
                    }
                    .font(.caption)
                }
                
                Link(destination: URL(string: "https://github.com/victor0602/minimax-status-bar")!) {
                    HStack {
                        Image(systemName: "curlybraces")
                        Text("GitHub 源码")
                    }
                    .font(.caption)
                }
            }
            
            Spacer()
            
            Text("MIT License")
                .font(.caption2)
                .foregroundColor(.tertiary)
        }
        .padding()
    }
}
```

- [ ] **Step 2: 验证编译**

Run: `cd /Users/victor/Documents/new\ workspace/minimax-status-bar && xcodebuild build -scheme minimax-status-bar -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)" | head -5`

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 提交**

```bash
cd /Users/victor/Documents/new\ workspace/minimax-status-bar
git add Sources/UI/SettingsView.swift
git commit -m "feat: add SettingsView with UsageHistory tab and SwiftUI Charts"
```

---

## Task 7: 集成设置入口到 DetailView

**Files:**
- Modify: `Sources/UI/DetailView.swift` (添加设置入口按钮)

- [ ] **Step 1: 在 DetailView 中添加设置入口**

在 `bottomBar` 视图中添加设置按钮：

```swift
private var bottomBar: some View {
    VStack(spacing: 4) {
        HStack(spacing: 8) {
            settingsButton  // 新增
            Spacer()
            exitButton
            // ... 其余按钮
        }
        versionBar
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
}

private var settingsButton: some View {
    Button(action: {
        // 打开设置窗口
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }) {
        Image(systemName: "gear")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
    }
    .buttonStyle(.plain)
    .help("设置")
}
```

- [ ] **Step 2: 在 AppDelegate 中添加设置窗口方法**

```swift
// 在 AppDelegate.swift 中添加
@objc func showSettingsWindow(_ sender: Any?) {
    let settingsView = SettingsView()
    let hostingController = NSHostingController(rootView: settingsView)
    
    let window = NSWindow(contentViewController: hostingController)
    window.title = "设置"
    window.styleMask = [.titled, .closable]
    window.setContentSize(NSSize(width: 420, height: 480))
    window.center()
    window.makeKeyAndOrderFront(nil)
}
```

- [ ] **Step 3: 验证编译**

Run: `cd /Users/victor/Documents/new\ workspace/minimax-status-bar && xcodebuild build -scheme minimax-status-bar -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)" | head -5`

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: 提交**

```bash
cd /Users/victor/Documents/new\ workspace/minimax-status-bar
git add Sources/UI/DetailView.swift Sources/App/AppDelegate.swift
git commit -m "feat: add settings entry to DetailView and AppDelegate"
```

---

## Task 8: 最终验证

- [ ] **Step 1: 运行所有测试**

Run: `cd /Users/victor/Documents/new\ workspace/minimax-status-bar && xcodebuild test -scheme minimax-status-bar -destination 'platform=macOS' 2>&1 | grep -E "(Executed|passed|failed)"`

Expected: `Executed 40+ tests, 0 failures`

- [ ] **Step 2: 验证构建**

Run: `cd /Users/victor/Documents/new\ workspace/minimax-status-bar && xcodebuild build -scheme minimax-status-bar -destination 'platform=macOS' 2>&1 | grep -E "(BUILD|warning:)" | head -10`

Expected: `BUILD SUCCEEDED`，无 warning

- [ ] **Step 3: 提交最终版本**

```bash
cd /Users/victor/Documents/new\ workspace/minimax-status-bar
git add .
git commit -m "feat: implement usage history and network monitoring features

- Add UsageRecord model with daily/weekly/monthly/yearly aggregations
- Add UsageHistoryService for data storage and querying
- Add NetworkMonitor using NWPathMonitor for network status
- Add SettingsView with Usage History tab using SwiftUI Charts
- Integrate network monitoring into StatusBarController
- Auto-record daily usage after successful API fetch

Closes #implementation"
```

---

## 自检清单

- [ ] Spec 覆盖：每个设计需求都有对应的任务实现
- [ ] 占位符扫描：无 TBD、TODO 或模糊需求
- [ ] 类型一致性：方法签名和属性名在所有任务中一致
- [ ] 测试覆盖：所有新功能都有单元测试
- [ ] 编译验证：所有任务都通过编译

---

## 执行选项

**Plan complete and saved to `docs/superpowers/plans/2026-04-12-usage-history-plan.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
