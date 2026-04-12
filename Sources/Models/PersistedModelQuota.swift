import Foundation

/// `ModelQuota` 磁盘快照（Codable）；用于离线缓存与 `QuotaStatePersistence`。
struct PersistedModelQuota: Codable, Equatable {
    let modelName: String
    let totalCount: Int
    let intervalConsumedCount: Int
    let remainingCount: Int
    let intervalConsumedPercent: Int
    let weeklyTotalCount: Int
    let weeklyConsumedCount: Int
    let weeklyRemainingCount: Int
    let remainsTimeMs: Int64
    let weeklyStartTime: TimeInterval
    let weeklyEndTime: TimeInterval
    let fetchedAt: TimeInterval

    init(from model: ModelQuota) {
        modelName = model.modelName
        totalCount = model.totalCount
        intervalConsumedCount = model.intervalConsumedCount
        remainingCount = model.remainingCount
        intervalConsumedPercent = model.intervalConsumedPercent
        weeklyTotalCount = model.weeklyTotalCount
        weeklyConsumedCount = model.weeklyConsumedCount
        weeklyRemainingCount = model.weeklyRemainingCount
        remainsTimeMs = model.remainsTimeMs
        weeklyStartTime = model.weeklyStartTime.timeIntervalSinceReferenceDate
        weeklyEndTime = model.weeklyEndTime.timeIntervalSinceReferenceDate
        fetchedAt = model.fetchedAt.timeIntervalSinceReferenceDate
    }

    func toModelQuota() -> ModelQuota {
        ModelQuota(
            modelName: modelName,
            totalCount: totalCount,
            intervalConsumedCount: intervalConsumedCount,
            remainingCount: remainingCount,
            intervalConsumedPercent: intervalConsumedPercent,
            weeklyTotalCount: weeklyTotalCount,
            weeklyConsumedCount: weeklyConsumedCount,
            weeklyRemainingCount: weeklyRemainingCount,
            remainsTimeMs: remainsTimeMs,
            weeklyStartTime: Date(timeIntervalSinceReferenceDate: weeklyStartTime),
            weeklyEndTime: Date(timeIntervalSinceReferenceDate: weeklyEndTime),
            fetchedAt: Date(timeIntervalSinceReferenceDate: fetchedAt)
        )
    }
}
