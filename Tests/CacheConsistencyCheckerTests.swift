import XCTest
@testable import MiniMax_Status_Bar

final class CacheConsistencyCheckerTests: XCTestCase {
    func testValidModelsProduceNoIssues() {
        // API usage=75, total=100 → remaining=25
        let raw = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalUsageCount: 75,
            currentWeeklyTotalCount: 1000,
            currentWeeklyUsageCount: 600,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let m = ModelQuota.from(raw: raw)
        XCTAssertTrue(CacheConsistencyChecker.modelsLookConsistent([m]))
        XCTAssertTrue(CacheConsistencyChecker.validationIssues(for: [m]).isEmpty)
    }

    func testRemainingGreaterThanTotalIsFlagged() {
        // API usage=15, total=10 → remaining=-5（负数，不合理），应被标记
        let raw = ModelQuotaRaw(
            modelName: "bad",
            currentIntervalTotalCount: 10,
            currentIntervalUsageCount: 15,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
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
            // API usage=90, total=100 → remaining=90
            ModelQuota.from(raw: ModelQuotaRaw(
                modelName: name,
                currentIntervalTotalCount: 100,
                currentIntervalUsageCount: 90,
                currentWeeklyTotalCount: 0,
                currentWeeklyUsageCount: 0,
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
        // cached: usage=10, total=100 → remaining=90
        let cached = [ModelQuota.from(raw: ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalUsageCount: 10,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        ))]
        // new: usage=10, total=200 → remaining=190
        let newModels = [ModelQuota.from(raw: ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 200,
            currentIntervalUsageCount: 10,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
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
        // API usage=75, total=100 → remaining=75
        let raw1 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalUsageCount: 75,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let raw2 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalUsageCount: 75,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let m1 = ModelQuota.from(raw: raw1)
        let m2 = ModelQuota.from(raw: raw2)
        XCTAssertEqual(CacheConsistencyChecker.checksum(for: [m1]), CacheConsistencyChecker.checksum(for: [m2]))
    }

    func testChecksum_DifferentModelsProduceDifferentChecksum() {
        // raw1: usage=75, total=100 → remaining=75
        let raw1 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalUsageCount: 75,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        // raw2: usage=25, total=200 → remaining=175
        let raw2 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 200,
            currentIntervalUsageCount: 25,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let m1 = ModelQuota.from(raw: raw1)
        let m2 = ModelQuota.from(raw: raw2)
        XCTAssertNotEqual(CacheConsistencyChecker.checksum(for: [m1]), CacheConsistencyChecker.checksum(for: [m2]))
    }

    func testChecksum_OrderIndependent() {
        // A: usage=75, total=100 → remaining=75
        let rawA = ModelQuotaRaw(
            modelName: "A",
            currentIntervalTotalCount: 100,
            currentIntervalUsageCount: 75,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        // B: usage=150, total=200 → remaining=50
        let rawB = ModelQuotaRaw(
            modelName: "B",
            currentIntervalTotalCount: 200,
            currentIntervalUsageCount: 150,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
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
        // API usage=75, total=100 → remaining=75
        let raw = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalUsageCount: 75,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
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
        // usage=50, total=100 → remaining=50
        let raw1 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalUsageCount: 50,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let raw2 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalUsageCount: 50,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let m1 = ModelQuota.from(raw: raw1)
        let m2 = ModelQuota.from(raw: raw2)
        XCTAssertTrue(CacheConsistencyChecker.modelsAreSubstantiallySame([m1], [m2]))
    }

    func testModelsAreSubstantiallySame_SmallDifferenceAllowed() {
        // m1: usage=50, total=100 → remaining=50
        // m2: usage=52, total=100 → remaining=48
        // 剩余量差2，阈值=100/20=5，允许
        let raw1 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalUsageCount: 50,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let raw2 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalUsageCount: 52,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let m1 = ModelQuota.from(raw: raw1)
        let m2 = ModelQuota.from(raw: raw2)
        XCTAssertTrue(CacheConsistencyChecker.modelsAreSubstantiallySame([m1], [m2]))
    }

    func testModelsAreSubstantiallySame_LargeDifferenceNotAllowed() {
        // m1: usage=50, total=100 → remaining=50
        // m2: usage=60, total=100 → remaining=40
        // 剩余量差10，阈值=100/20=5，不允许
        let raw1 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalUsageCount: 50,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let raw2 = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalUsageCount: 60,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
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
        // usage=50, total=100 → remaining=50
        let raw = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalUsageCount: 50,
            currentWeeklyTotalCount: 0,
            currentWeeklyUsageCount: 0,
            remainsTime: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0
        )
        let m = ModelQuota.from(raw: raw)
        XCTAssertFalse(CacheConsistencyChecker.modelsAreSubstantiallySame([m], []))
        XCTAssertFalse(CacheConsistencyChecker.modelsAreSubstantiallySame([], [m]))
    }
}
