import Foundation
import SQLite

/// 用量历史 Store：按日一条 `DailyUsageRecord` JSON，使用 SQLite 持久化。
///
/// 约束：
/// - API/UI 层以“按日 upsert、按日读取”为主，避免写入频率过高。
/// - 保留策略默认最近 30 天（见 `purgeRecords`）。
final class UsageHistorySQLiteStore {
    static let shared = UsageHistorySQLiteStore()
    static let defaultRetentionDays: Int = 30

    private var db: Connection?
    private let table = Table("daily_usage")
    private let dateKeyCol = Expression<String>("date_key")
    private let payloadCol = Expression<String>("payload")

    private init() {
        do {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("MiniMaxStatusBar", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("usage_history.sqlite3")
            let conn = try Connection(url.path)
            conn.busyTimeout = 5
            try conn.run(table.create(ifNotExists: true) { t in
                t.column(dateKeyCol, primaryKey: true)
                t.column(payloadCol)
            })
            db = conn
        } catch {
            db = nil
        }
    }

    func upsertDailyRecord(_ record: DailyUsageRecord) throws {
        guard let db else { throw NSError(domain: "UsageHistory", code: 1) }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(record)
        guard let json = String(data: data, encoding: .utf8) else { return }
        try db.run(table.insert(or: OnConflict.replace, dateKeyCol <- record.dateKey, payloadCol <- json))
    }

    func loadDailyRecords(limit: Int) throws -> [DailyUsageRecord] {
        guard let db else { return [] }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        var out: [DailyUsageRecord] = []
        let q = table.order(dateKeyCol.desc).limit(limit)
        for row in try db.prepare(q) {
            let json = row[payloadCol]
            guard let d = json.data(using: .utf8),
                  let rec = try? dec.decode(DailyUsageRecord.self, from: d) else { continue }
            out.append(rec)
        }
        return out
    }

    func exportAllRecordsCSV() throws -> String {
        let records = try loadDailyRecords(limit: 10_000)
        var lines = ["date_key,primary_model,total_consumed"]
        for r in records.sorted(by: { $0.dateKey < $1.dateKey }) {
            lines.append("\(r.dateKey),\(r.primaryModelName.replacingOccurrences(of: ",", with: ";")),\(r.totalConsumed)")
        }
        return lines.joined(separator: "\n")
    }

    func purgeRecords(keepingDays: Int = UsageHistorySQLiteStore.defaultRetentionDays, now: Date = Date()) throws {
        guard let db else { return }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        guard let cutoff = calendar.date(byAdding: .day, value: -keepingDays, to: startOfToday) else { return }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let cutoffKey = fmt.string(from: cutoff)

        let q = table.filter(dateKeyCol < cutoffKey)
        _ = try db.run(q.delete())
    }
}
