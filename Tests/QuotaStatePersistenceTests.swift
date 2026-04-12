import XCTest
@testable import MiniMax_Status_Bar

final class QuotaStatePersistenceTests: XCTestCase {
    @MainActor
    func testQuotaStateLoadsInitialCacheFromPersistence() {
        let raw = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalRemainingCount: 50,
            currentWeeklyTotalCount: 1000,
            currentWeeklyRemainingCount: 500,
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
        let raw = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 10,
            currentIntervalRemainingCount: 3,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
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
