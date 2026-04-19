import XCTest
@testable import MiniMax_Status_Bar

final class CacheConsistencyCheckerTests: XCTestCase {
    func testValidModelsProduceNoIssues() {
        // API remaining=25, total=100 → consumed=75
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
        // remaining=15, total=10 → 不合理，应被标记
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
            // remaining=10, total=100
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
        // cached: remaining=90, total=100
        let cached = [ModelQuota.from(raw: ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalRemainingCount: 90,
            currentWeeklyTotalCount: 0,
            currentWeeklyRemainingCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        ))]
        // new: remaining=190, total=200
        let newModels = [ModelQuota.from(raw: ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 200,
            currentIntervalRemainingCount: 190,
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
        // remaining=25, total=100
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
        // raw1: remaining=25, total=100
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
        // raw2: remaining=25, total=200
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
        // A: remaining=25, total=100
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
        // B: remaining=50, total=200
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
        XCTAssertEqual(CacheConsistencyChecker.checksum(for: [mA, mB]), CacheConsistencyChecker.checksum(for: [mB, mA]))
    }

    func testValidateChecksum_ReturnsTrueForMatching() {
        // remaining=25, total=100
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
        // remaining=50, total=100
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
        // m1: remaining=50, total=100
        // m2: remaining=48, total=100
        // 剩余量差2，阈值=100/20=5，允许
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
            currentIntervalRemainingCount: 48,
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
        // m1: remaining=50, total=100
        // m2: remaining=40, total=100
        // 剩余量差10，阈值=100/20=5，不允许
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
            currentIntervalRemainingCount: 40,
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
        // remaining=50, total=100
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
