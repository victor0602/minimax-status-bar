import Foundation

/// 每次拉取成功后写入当日用量快照（供历史图表 / 导出）。
@MainActor
enum UsageHistoryRecorder {
    private static let calendar = Calendar.current
    private static let lastPurgeKey = "UsageHistoryLastPurgeDateKey"

    static func recordSnapshot(models: [ModelQuota], primaryModelName: String) {
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let usages: [ModelUsage] = models.map {
            ModelUsage(
                modelName: $0.modelName,
                consumed: $0.intervalConsumedCount,
                total: $0.totalCount
            )
        }
        let totalConsumed = usages.reduce(0) { $0 + $1.consumed }
        let record = DailyUsageRecord(
            date: startOfDay,
            modelUsages: usages,
            primaryModelName: primaryModelName,
            totalConsumed: totalConsumed
        )
        Task { @MainActor in
            try? UsageHistorySQLiteStore.shared.upsertDailyRecord(record)
            purgeIfNeeded(now: now)
        }
    }

    /// 保留最近 30 天数据；每天本地时间 3:00 之后执行一次清理（无需后台常驻任务）。
    private static func purgeIfNeeded(now: Date) {
        let hour = calendar.component(.hour, from: now)
        guard hour >= 3 else { return }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let todayKey = fmt.string(from: calendar.startOfDay(for: now))

        let defaults = UserDefaults.standard
        if defaults.string(forKey: lastPurgeKey) == todayKey { return }

        try? UsageHistorySQLiteStore.shared.purgeRecords(now: now)
        defaults.set(todayKey, forKey: lastPurgeKey)
    }
}
