import XCTest
@testable import MiniMax_Status_Bar

final class ModelQuotaTests: XCTestCase {
    func testFromRawComputesRemainingAndPercent() {
        // API 返回 usage_count = 已用次数。total=100, 已用=75 → 剩余=25
        let raw = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalUsageCount: 75,
            currentWeeklyTotalCount: 1000,
            currentWeeklyUsageCount: 600,
            remainsTime: 3_600_000,
            weeklyStartTime: 0,
            weeklyEndTime: 86_400_000
        )

        let q = ModelQuota.from(raw: raw)
        XCTAssertEqual(q.remainingCount, 25)
        XCTAssertEqual(q.totalCount, 100)
        XCTAssertEqual(q.remainingPercent, 25)
        XCTAssertEqual(q.intervalConsumedPercent, 75)
        XCTAssertEqual(q.weeklyConsumedCount, 600)
        XCTAssertEqual(q.weeklyRemainingCount, 400)
        XCTAssertEqual(q.statusBarAbbreviation, "2.7·")
        XCTAssertEqual(q.displayName, "MiniMax M2.7")
    }

    /// API usage_count = 已用；total=3 且已用=0 → 100% 剩余、0% 已用
    func testFromRawWhenTotalEqualsRemainingFieldMeansFullQuota() {
        let raw = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 3,
            currentIntervalUsageCount: 0,
            currentWeeklyTotalCount: 10,
            currentWeeklyUsageCount: 0,
            remainsTime: 1_000,
            weeklyStartTime: 0,
            weeklyEndTime: 86_400_000
        )
        let q = ModelQuota.from(raw: raw)
        XCTAssertEqual(q.remainingCount, 3)
        XCTAssertEqual(q.intervalConsumedCount, 0)
        XCTAssertEqual(q.remainingPercent, 100)
        XCTAssertEqual(q.intervalConsumedPercent, 0)
    }

    func testStatusBarAbbreviationForVideo() {
        // 已用=5, total=10 → 剩余=5
        let raw = ModelQuotaRaw(
            modelName: "hailuo-2.3-fast",
            currentIntervalTotalCount: 10,
            currentIntervalUsageCount: 5,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        XCTAssertEqual(ModelQuota.from(raw: raw).statusBarAbbreviation, "V·")
    }

    @MainActor
    func testPrimaryModelPrefersM27Name() {
        let mock = MockQuotaPersistence()
        mock.loadReturn = nil
        let state = QuotaState(persistence: mock)
        let a = ModelQuota.from(raw: ModelQuotaRaw(
            modelName: "other-model",
            currentIntervalTotalCount: 10,
            currentIntervalUsageCount: 5,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        ))
        let b = ModelQuota.from(raw: ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 10,
            currentIntervalUsageCount: 9,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        ))
        state.models = [a, b]
        XCTAssertEqual(state.primaryModel?.modelName, "MiniMax-M2.7")
    }
}
