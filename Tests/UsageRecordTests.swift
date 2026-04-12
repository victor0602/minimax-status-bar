import XCTest
@testable import MiniMax_Status_Bar

final class UsageRecordTests: XCTestCase {
    func testDailyUsageRecordCodable() throws {
        let record = DailyUsageRecord(
            date: Date(),
            modelUsages: [
                ModelUsage(modelName: "MiniMax-M2.7", consumed: 5000, total: 10000),
                ModelUsage(modelName: "hailuo-video", consumed: 100, total: 1000)
            ],
            primaryModelName: "MiniMax-M2.7",
            totalConsumed: 5100
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(record)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DailyUsageRecord.self, from: data)
        
        XCTAssertEqual(decoded.primaryModelName, "MiniMax-M2.7")
        XCTAssertEqual(decoded.totalConsumed, 5100)
        XCTAssertEqual(decoded.modelUsages.count, 2)
    }
    
    func testModelUsageCalculation() {
        let usage = ModelUsage(modelName: "MiniMax-M2.7", consumed: 2500, total: 10000)
        XCTAssertEqual(usage.consumedPercent, 25)
        XCTAssertEqual(usage.remaining, 7500)
    }
    
    func testWeeklyAggregation() throws {
        let records = try createWeeklyRecords()
        let aggregated = WeeklyAggregation.aggregate(from: records)
        
        XCTAssertNotNil(aggregated)
        XCTAssertEqual(aggregated?.totalConsumed, 35000)
        XCTAssertEqual(aggregated?.primaryModelName, "MiniMax-M2.7")
    }
    
    func testMonthlyAggregation() throws {
        let records = try createMonthRecords()
        let aggregated = MonthlyAggregation.aggregate(from: records)
        
        XCTAssertNotNil(aggregated)
        XCTAssertEqual(aggregated?.totalConsumed, 150000)
    }
    
    func testYearlyAggregation() throws {
        let monthlies = try createMonthlies()
        let aggregated = YearlyAggregation.aggregate(from: monthlies)
        
        XCTAssertNotNil(aggregated)
        XCTAssertEqual(aggregated?.year, "2026")
        XCTAssertEqual(aggregated?.primaryModelName, "MiniMax-M2.7")
    }
    
    func testDailyUsageRecordDateKey() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 12
        let date = calendar.date(from: components) ?? Date()
        
        let record = DailyUsageRecord(
            date: date,
            modelUsages: [],
            primaryModelName: "test",
            totalConsumed: 100
        )
        
        XCTAssertEqual(record.dateKey, "2026-04-12")
        XCTAssertEqual(record.formattedDate, "4/12")
    }
    
    private func createWeeklyRecords() throws -> [DailyUsageRecord] {
        let calendar = Calendar.current
        let today = Date()
        var records: [DailyUsageRecord] = []
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                throw NSError(domain: "Test", code: 0)
            }
            let record = DailyUsageRecord(
                date: date,
                modelUsages: [ModelUsage(modelName: "MiniMax-M2.7", consumed: 5000, total: 10000)],
                primaryModelName: "MiniMax-M2.7",
                totalConsumed: 5000
            )
            records.append(record)
        }
        return records
    }
    
    /// All days in one calendar month so `MonthlyAggregation` (which keeps only the first record’s `yyyy-MM`) sums 30 × 5000.
    private func createMonthRecords() throws -> [DailyUsageRecord] {
        let calendar = Calendar.current
        var records: [DailyUsageRecord] = []
        for day in 1...30 {
            var c = DateComponents()
            c.year = 2026
            c.month = 4
            c.day = day
            guard let date = calendar.date(from: c) else {
                throw NSError(domain: "Test", code: 0, userInfo: nil)
            }
            records.append(DailyUsageRecord(
                date: date,
                modelUsages: [ModelUsage(modelName: "MiniMax-M2.7", consumed: 5000, total: 10000)],
                primaryModelName: "MiniMax-M2.7",
                totalConsumed: 5000
            ))
        }
        return records
    }
    
    private func createMonthlies() throws -> [MonthlyAggregation] {
        var monthlies: [MonthlyAggregation] = []
        for month in 1...12 {
            let monthStr = String(format: "2026-%02d", month)
            let aggregation = MonthlyAggregation(
                yearMonth: monthStr,
                totalConsumed: 100000,
                primaryModelName: "MiniMax-M2.7",
                primaryModelConsumed: 80000,
                recordCount: 25
            )
            monthlies.append(aggregation)
        }
        return monthlies
    }
}
