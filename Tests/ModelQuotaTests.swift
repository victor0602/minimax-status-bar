import XCTest
@testable import MiniMax_Status_Bar

final class ModelQuotaTests: XCTestCase {
    func testFromRawComputesRemainingAndPercent() {
        let raw = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalUsageCount: 25,
            currentWeeklyTotalCount: 1000,
            currentWeeklyUsageCount: 400,
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
    }

    func testStatusBarAbbreviationForVideo() {
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
        let state = QuotaState()
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
