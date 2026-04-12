import Foundation

/// 每次拉取成功后写入当日用量快照（供历史图表 / 导出）。
@MainActor
enum UsageHistoryRecorder {
    private static let calendar = Calendar.current

    static func recordSnapshot(models: [ModelQuota], primaryModelName: String) {
        let startOfDay = calendar.startOfDay(for: Date())
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
        }
    }
}
