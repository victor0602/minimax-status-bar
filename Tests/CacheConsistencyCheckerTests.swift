import XCTest
@testable import MiniMax_Status_Bar

final class CacheConsistencyCheckerTests: XCTestCase {
    func testValidModelsProduceNoIssues() {
        let raw = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalRemainingCount: 25,
            currentWeeklyTotalCount: 1000,
            currentWeeklyRemainingCount: 400,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let m = ModelQuota.from(raw: raw)
        XCTAssertTrue(CacheConsistencyChecker.modelsLookConsistent([m]))
        XCTAssertTrue(CacheConsistencyChecker.validationIssues(for: [m]).isEmpty)
    }

    func testRemainingGreaterThanTotalIsFlagged() {
        let raw = ModelQuotaRaw(
            modelName: "bad",
            currentIntervalTotalCount: 10,
            currentIntervalRemainingCount: 15,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let m = ModelQuota.from(raw: raw)
        XCTAssertFalse(CacheConsistencyChecker.modelsLookConsistent([m]))
        XCTAssertFalse(CacheConsistencyChecker.validationIssues(for: [m]).isEmpty)
    }

    func testValidateAgainstCache_FlagsMissingModelsWhenManyDisappear() {
        func raw(name: String) -> ModelQuota {
            ModelQuota.from(raw: ModelQuotaRaw(
                modelName: name,
                currentIntervalTotalCount: 100,
                currentIntervalRemainingCount: 10,
                currentWeeklyTotalCount: 0,
                currentWeeklyRemainingCount: 0,
                remainsTime: 0,
                weeklyStartTime: 0,
                weeklyEndTime: 0
            ))
        }

        let cached = [raw(name: "A"), raw(name: "B"), raw(name: "C"), raw(name: "D")]
        let newModels = [raw(name: "A")]
        let issues = CacheConsistencyChecker.validationIssues(for: newModels, against: cached)
        XCTAssertFalse(issues.isEmpty)
    }

    func testValidateAgainstCache_FlagsTotalCountChange() {
        let cached = [ModelQuota.from(raw: ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalRemainingCount: 10,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        ))]
        let newModels = [ModelQuota.from(raw: ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 200,
            currentIntervalRemainingCount: 10,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        ))]

        let issues = CacheConsistencyChecker.validationIssues(for: newModels, against: cached)
        XCTAssertTrue(issues.contains(where: { $0.contains("totalCount changed") }))
    }
}
