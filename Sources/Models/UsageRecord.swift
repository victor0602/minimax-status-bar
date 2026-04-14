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

// MARK: - 共享 DateFormatter 实例（避免重复创建开销）

/// 日期格式化器 - 日期键（yyyy-MM-dd）
private let dateKeyFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

/// 日期格式化器 - 短日期（M/d）
private let shortDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "M/d"
    return f
}()

/// 日期格式化器 - 周键（yyyy-'W'ww）
private let weekKeyFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-'W'ww"
    return f
}()

/// 日期格式化器 - 月键（yyyy-MM）
private let monthKeyFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM"
    return f
}()

/// 日期格式化器 - 月份名称（yyyy年M月）
private let monthNameFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy年M月"
    return f
}()

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
        dateKeyFormatter.string(from: date)
    }
    
    /// 格式化日期显示
    var formattedDate: String {
        shortDateFormatter.string(from: date)
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
        "\(shortDateFormatter.string(from: weekStartDate))-\(shortDateFormatter.string(from: weekEndDate))"
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
        
        let weekKey = weekKeyFormatter.string(from: weekStart)
        
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
        if let date = monthKeyFormatter.date(from: yearMonth) {
            return monthNameFormatter.string(from: date)
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
        
        // 按月分组
        let monthKey = monthKeyFormatter.string(from: records[0].date)
        let monthRecords = records.filter { monthKeyFormatter.string(from: $0.date) == monthKey }
        
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
