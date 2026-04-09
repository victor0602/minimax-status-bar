import Foundation
import SQLite

class DataPersistenceService {
    private var db: Connection?

    private let usageHistory = Table("usage_history")
    private let id = SQLite.Expression<Int64>("id")
    private let date = SQLite.Expression<String>("date")
    private let usedTokens = SQLite.Expression<Int64>("used_tokens")
    private let totalTokens = SQLite.Expression<Int64>("total_tokens")
    private let totalCalls = SQLite.Expression<Int64>("total_calls")
    private let errorRateCol = SQLite.Expression<Double>("error_rate")
    private let avgResponseTime = SQLite.Expression<Double>("avg_response_time")

    init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let path = getDatabasePath()
            db = try Connection(path)
            try createTables()
        } catch {
            print("Database setup error: \(error)")
        }
    }

    private func getDatabasePath() -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("MiniMaxStatusBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("data.sqlite3").path
    }

    private func createTables() throws {
        try db?.run(usageHistory.create(ifNotExists: true) { t in
            t.column(id, primaryKey: .autoincrement)
            t.column(date)
            t.column(usedTokens)
            t.column(totalTokens)
            t.column(totalCalls)
            t.column(errorRateCol)
            t.column(avgResponseTime)
        })
    }

    func saveUsageRecord(usage: TokenUsage, stats: APIStats) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())

        do {
            let insert = usageHistory.insert(
                date <- dateString,
                usedTokens <- Int64(usage.usedTokens),
                totalTokens <- Int64(usage.totalTokens),
                totalCalls <- Int64(stats.totalCalls),
                errorRateCol <- stats.errorRate,
                avgResponseTime <- stats.avgResponseTime
            )
            try db?.run(insert)
        } catch {
            print("Insert error: \(error)")
        }
    }

    func getTodayUsage() -> (used: Int, total: Int)? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())

        do {
            let query = usageHistory.filter(date == dateString).order(id.desc).limit(1)
            if let row = try db?.pluck(query) {
                return (used: Int(row[usedTokens]), total: Int(row[totalTokens]))
            }
        } catch {
            print("Query error: \(error)")
        }
        return nil
    }
}
