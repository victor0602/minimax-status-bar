import XCTest
@testable import MiniMax_Status_Bar

final class ModelQuotaTests: XCTestCase {
    func testFromRawComputesRemainingAndPercent() {
        // API 返回 remaining=25, total=100 → consumed=75
        let raw = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalRemainingCount: 25,
            currentWeeklyTotalCount: 1000,
            currentWeeklyRemainingCount: 400,
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

    /// API 返回 remaining=3, total=3 → consumed=0, 100% 剩余
    /// 略低于总额时整数除法为 99%；与 `formatCountForDisplay` 的「30.0K/30.0K」错觉不同，应用 `formatCountForQuotaDetail` 展示精确剩余。
    func testRemainingPercentWhenSlightlyBelowTotal() {
        let raw = ModelQuotaRaw(
            modelName: "minimax-m",
            currentIntervalTotalCount: 30_000,
            currentIntervalRemainingCount: 29_951,
            currentWeeklyTotalCount: 30_000,
            currentWeeklyRemainingCount: 29_951,
            remainsTime: 1_000,
            weeklyStartTime: 0,
            weeklyEndTime: 86_400_000
        )
        let q = ModelQuota.from(raw: raw)
        XCTAssertEqual(q.remainingPercent, 99)
        XCTAssertEqual(q.intervalConsumedPercent, 1)
    }

    func testFromRawWhenTotalEqualsRemainingFieldMeansFullQuota() {
        let raw = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 3,
            currentIntervalRemainingCount: 3,
            currentWeeklyTotalCount: 10,
            currentWeeklyRemainingCount: 10,
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
        // remaining=5, total=10 → consumed=5
        let raw = ModelQuotaRaw(
            modelName: "hailuo-2.3-fast",
            currentIntervalTotalCount: 10,
            currentIntervalRemainingCount: 5,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
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
            currentIntervalRemainingCount: 5,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        ))
        let b = ModelQuota.from(raw: ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 10,
            currentIntervalRemainingCount: 9,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        ))
        state.models = [a, b]
        XCTAssertEqual(state.primaryModel?.modelName, "MiniMax-M2.7")
    }
}
