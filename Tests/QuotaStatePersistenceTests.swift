import XCTest
@testable import MiniMax_Status_Bar

final class QuotaStatePersistenceTests: XCTestCase {
    @MainActor
    func testQuotaStateLoadsInitialCacheFromPersistence() {
        // API usage=50, total=100 → remaining=50
        let raw = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalUsageCount: 50,
            currentWeeklyTotalCount: 1000,
            currentWeeklyUsageCount: 500,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 86_400_000
        )
        let m = ModelQuota.from(raw: raw)
        let mock = MockQuotaPersistence()
        mock.loadReturn = ([m], Date(timeIntervalSince1970: 1_700_000_000))
        let state = QuotaState(persistence: mock)
        XCTAssertEqual(state.cachedModels.count, 1)
        XCTAssertEqual(state.cachedModels.first?.remainingCount, 50)
        XCTAssertNotNil(state.cachedAt)
    }

    @MainActor
    func testCommitSuccessfulFetchPersistsViaPersistence() {
        let mock = MockQuotaPersistence()
        let state = QuotaState(persistence: mock)
        // API usage=7, total=10 → remaining=3
        let raw = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 10,
            currentIntervalUsageCount: 7,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let models = [ModelQuota.from(raw: raw)]
        state.commitSuccessfulFetch(models: models)
        XCTAssertEqual(mock.saved?.0.count, 1)
        XCTAssertEqual(state.models.first?.remainingCount, 3)
    }
}
