import XCTest
@testable import MiniMax_Status_Bar

final class HistoryAnalyticsTests: XCTestCase {
    func testRangeRecordsReturnsExpectedCount() {
        let records = makeRecords(days: 30, baseConsumed: 100)
        let analytics = HistoryAnalytics(allRecords: records, rangeDays: 7)

        XCTAssertEqual(analytics.rangeRecords.count, 7)
    }

    func testAggregatesChangeByRange() {
        let records = makeRecords(days: 30, baseConsumed: 100)

        let last7 = HistoryAnalytics(allRecords: records, rangeDays: 7)
        let last30 = HistoryAnalytics(allRecords: records, rangeDays: 30)

        XCTAssertTrue(last30.totalConsumed > last7.totalConsumed)
        XCTAssertTrue(last30.averageConsumed >= last7.averageConsumed)
    }

    func testPeakRecordDetectsMaximumConsumed() {
        var records = makeRecords(days: 10, baseConsumed: 100)
        let calendar = Calendar.current
        let peakDate = calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        records.append(
            DailyUsageRecord(
                date: peakDate,
                modelUsages: [ModelUsage(modelName: "minimax-m", consumed: 9999, total: 30000)],
                primaryModelName: "minimax-m",
                totalConsumed: 9999
            )
        )

        let analytics = HistoryAnalytics(allRecords: records, rangeDays: 14)
        XCTAssertEqual(analytics.peakRecord?.totalConsumed, 9999)
    }

    private func makeRecords(days: Int, baseConsumed: Int) -> [DailyUsageRecord] {
        let calendar = Calendar.current
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else {
                return nil
            }
            let consumed = baseConsumed + (offset * 10)
            return DailyUsageRecord(
                date: date,
                modelUsages: [ModelUsage(modelName: "minimax-m", consumed: consumed, total: 30000)],
                primaryModelName: "minimax-m",
                totalConsumed: consumed
            )
        }
    }
}

