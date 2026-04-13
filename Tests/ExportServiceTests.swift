import XCTest
@testable import MiniMax_Status_Bar

final class ExportServiceTests: XCTestCase {
    var service: ExportService!

    override func setUp() {
        super.setUp()
        service = ExportService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    func testGenerateCSV_WithSingleRecord() {
        let records = [
            DailyUsageRecord(
                date: Date(timeIntervalSince1970: 0),
                modelUsages: [ModelUsage(modelName: "MiniMax-M2.7", consumed: 5000, total: 10000)],
                primaryModelName: "MiniMax-M2.7",
                totalConsumed: 5000
            )
        ]

        let csv = service.generateCSV(from: records)

        XCTAssertTrue(csv.hasPrefix(ExportService.csvHeader))
        XCTAssertTrue(csv.contains("1970-01-01"))
        XCTAssertTrue(csv.contains("MiniMax-M2.7"))
        XCTAssertTrue(csv.contains("5000"))
    }

    func testGenerateCSV_WithMultipleRecords() {
        let records = [
            DailyUsageRecord(
                date: Date(timeIntervalSince1970: 0),
                modelUsages: [ModelUsage(modelName: "MiniMax-M2.7", consumed: 3000, total: 10000)],
                primaryModelName: "MiniMax-M2.7",
                totalConsumed: 3000
            ),
            DailyUsageRecord(
                date: Date(timeIntervalSince1970: 86400),
                modelUsages: [ModelUsage(modelName: "Hailuo-2.3", consumed: 500, total: 1000)],
                primaryModelName: "Hailuo-2.3",
                totalConsumed: 500
            )
        ]

        let csv = service.generateCSV(from: records)
        let lines = csv.components(separatedBy: "\n")

        // Header + 2 data lines
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(csv.contains("MiniMax-M2.7"))
        XCTAssertTrue(csv.contains("Hailuo-2.3"))
    }

    func testGenerateCSV_SortsByDateKeyAscending() {
        let records = [
            createRecord(daysAgo: 5, modelName: "Day5"),
            createRecord(daysAgo: 1, modelName: "Day1"),
            createRecord(daysAgo: 3, modelName: "Day3")
        ]

        let csv = service.generateCSV(from: records)
        let lines = csv.components(separatedBy: "\n")

        // Find data lines (skip header)
        let dataLines = lines.dropFirst().filter { !$0.isEmpty }
        XCTAssertEqual(dataLines.count, 3)

        // Verify order: Day5 should come first (earliest date), Day1 last (latest date)
        XCTAssertTrue(dataLines[0].contains("Day5"))
        XCTAssertTrue(dataLines[1].contains("Day3"))
        XCTAssertTrue(dataLines[2].contains("Day1"))
    }

    func testGenerateCSV_EscapesCommaInModelName() {
        let records = [
            DailyUsageRecord(
                date: Date(timeIntervalSince1970: 0),
                modelUsages: [],
                primaryModelName: "Model, With, Commas",
                totalConsumed: 100
            )
        ]

        let csv = service.generateCSV(from: records)

        // Commas should be escaped to semicolons
        XCTAssertTrue(csv.contains("Model; With; Commas"))
        XCTAssertFalse(csv.contains("Model, With, Commas"))
    }

    func testGenerateCSV_EmptyRecords() {
        let records: [DailyUsageRecord] = []

        let csv = service.generateCSV(from: records)
        let lines = csv.components(separatedBy: "\n")

        // Only header
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0], ExportService.csvHeader)
    }

    func testWriteCSV_ToTemporaryFile() throws {
        let records = [
            createRecord(daysAgo: 0, modelName: "Test")
        ]

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("csv")

        try service.writeCSV(from: records, to: tempURL)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let written = try String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertTrue(written.contains("Test"))
        XCTAssertTrue(written.hasPrefix(ExportService.csvHeader))
    }

    func testWriteCSV_OverwritesExistingFile() throws {
        let records1 = [createRecord(daysAgo: 0, modelName: "First")]
        let records2 = [createRecord(daysAgo: 0, modelName: "Second")]

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("csv")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        try service.writeCSV(from: records1, to: tempURL)
        try service.writeCSV(from: records2, to: tempURL)

        let written = try String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertTrue(written.contains("Second"))
        XCTAssertFalse(written.contains("First"))
    }

    func testDefaultFileName() {
        XCTAssertEqual(ExportService.defaultFileName, "minimax-usage-history.csv")
    }

    func testCSVHeader() {
        XCTAssertEqual(ExportService.csvHeader, "date_key,primary_model,total_consumed")
    }

    private func createRecord(daysAgo: Int, modelName: String) -> DailyUsageRecord {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return DailyUsageRecord(
            date: date,
            modelUsages: [ModelUsage(modelName: modelName, consumed: 100, total: 1000)],
            primaryModelName: modelName,
            totalConsumed: 100
        )
    }
}