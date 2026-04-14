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

    // MARK: - 校验和相关测试

    func testChecksum_EmptyModelsReturnsEmpty() {
        let checksum = CacheConsistencyChecker.checksum(for: [])
        XCTAssertEqual(checksum, "empty")
    }

    func testChecksum_SameModelsProduceSameChecksum() {
        let raw1 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalRemainingCount: 25,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let raw2 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalRemainingCount: 25,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let m1 = ModelQuota.from(raw: raw1)
        let m2 = ModelQuota.from(raw: raw2)
        XCTAssertEqual(CacheConsistencyChecker.checksum(for: [m1]), CacheConsistencyChecker.checksum(for: [m2]))
    }

    func testChecksum_DifferentModelsProduceDifferentChecksum() {
        let raw1 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalRemainingCount: 25,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let raw2 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 200,
            currentIntervalRemainingCount: 25,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let m1 = ModelQuota.from(raw: raw1)
        let m2 = ModelQuota.from(raw: raw2)
        XCTAssertNotEqual(CacheConsistencyChecker.checksum(for: [m1]), CacheConsistencyChecker.checksum(for: [m2]))
    }

    func testChecksum_OrderIndependent() {
        let rawA = ModelQuotaRaw(
            modelName: "A",
            currentIntervalTotalCount: 100,
            currentIntervalRemainingCount: 25,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let rawB = ModelQuotaRaw(
            modelName: "B",
            currentIntervalTotalCount: 200,
            currentIntervalRemainingCount: 50,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let mA = ModelQuota.from(raw: rawA)
        let mB = ModelQuota.from(raw: rawB)
        // 无论顺序如何，校验和应该相同
        XCTAssertEqual(CacheConsistencyChecker.checksum(for: [mA, mB]), CacheConsistencyChecker.checksum(for: [mB, mA]))
    }

    func testValidateChecksum_ReturnsTrueForMatching() {
        let raw = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalRemainingCount: 25,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let m = ModelQuota.from(raw: raw)
        let checksum = CacheConsistencyChecker.checksum(for: [m])
        XCTAssertTrue(CacheConsistencyChecker.validateChecksum([m], against: checksum))
    }

    // MARK: - 实质性一致测试

    func testModelsAreSubstantiallySame_IdenticalModels() {
        let raw1 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalRemainingCount: 50,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let raw2 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalRemainingCount: 50,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let m1 = ModelQuota.from(raw: raw1)
        let m2 = ModelQuota.from(raw: raw2)
        XCTAssertTrue(CacheConsistencyChecker.modelsAreSubstantiallySame([m1], [m2]))
    }

    func testModelsAreSubstantiallySame_SmallDifferenceAllowed() {
        let raw1 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalRemainingCount: 50,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let raw2 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalRemainingCount: 48, // 2 的差异，阈值是 100/20=5，所以允许
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let m1 = ModelQuota.from(raw: raw1)
        let m2 = ModelQuota.from(raw: raw2)
        XCTAssertTrue(CacheConsistencyChecker.modelsAreSubstantiallySame([m1], [m2]))
    }

    func testModelsAreSubstantiallySame_LargeDifferenceNotAllowed() {
        let raw1 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalRemainingCount: 50,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let raw2 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalRemainingCount: 40, // 10 的差异，阈值是 100/20=5，所以不允许
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let m1 = ModelQuota.from(raw: raw1)
        let m2 = ModelQuota.from(raw: raw2)
        XCTAssertFalse(CacheConsistencyChecker.modelsAreSubstantiallySame([m1], [m2]))
    }

    func testModelsAreSubstantiallySame_EmptyLists() {
        XCTAssertTrue(CacheConsistencyChecker.modelsAreSubstantiallySame([], []))
    }

    func testModelsAreSubstantiallySame_DifferentCounts() {
        let raw = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalRemainingCount: 50,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let m = ModelQuota.from(raw: raw)
        XCTAssertFalse(CacheConsistencyChecker.modelsAreSubstantiallySame([m], []))
        XCTAssertFalse(CacheConsistencyChecker.modelsAreSubstantiallySame([], [m]))
    }
}
