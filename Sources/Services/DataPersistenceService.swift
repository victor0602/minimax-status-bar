import Foundation
import SQLite

class DataPersistenceService: @unchecked Sendable {
    private var db: Connection?
    private let writeQueue = DispatchQueue(label: "com.openclaw.minimax-status-bar.db")

    private let usageHistory = Table("usage_history")
    private let id = SQLite.Expression<Int64>("id")
    private let recordedAt = SQLite.Expression<String>("recorded_at")
    private let modelName = SQLite.Expression<String>("model_name")
    private let totalCount = SQLite.Expression<Int64>("total_count")
    private let usageCount = SQLite.Expression<Int64>("usage_count")
    private let remainingCount = SQLite.Expression<Int64>("remaining_count")
    private let weeklyTotal = SQLite.Expression<Int64>("weekly_total")
    private let weeklyUsage = SQLite.Expression<Int64>("weekly_usage")

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
            t.column(recordedAt)
            t.column(modelName)
            t.column(totalCount)
            t.column(usageCount)
            t.column(remainingCount)
            t.column(weeklyTotal)
            t.column(weeklyUsage)
        })
    }

    func saveHistory(_ models: [ModelQuota]) {
        let dateStr = ISO8601DateFormatter().string(from: Date())
        let db = self.db

        writeQueue.async {
            guard let db = db else { return }
            do {
                for model in models {
                    let insert = self.usageHistory.insert(
                        self.recordedAt <- dateStr,
                        self.modelName <- model.modelName,
                        self.totalCount <- Int64(model.totalCount),
                        self.usageCount <- Int64(model.usageCount),
                        self.remainingCount <- Int64(model.remainingCount),
                        self.weeklyTotal <- Int64(model.weeklyTotal),
                        self.weeklyUsage <- Int64(model.weeklyUsage)
                    )
                    try db.run(insert)
                }
                self.cleanupOldRecords(db: db)
            } catch {
                print("Insert error: \(error)")
            }
        }
    }

    private func cleanupOldRecords(db: Connection?) {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -30, to: Date()) else { return }
        let cutoffStr = ISO8601DateFormatter().string(from: cutoffDate)

        do {
            let oldRecords = usageHistory.filter(recordedAt < cutoffStr)
            try db?.run(oldRecords.delete())
        } catch {
            print("Cleanup error: \(error)")
        }
    }
}
