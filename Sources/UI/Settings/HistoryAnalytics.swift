import Foundation

struct HistoryAnalytics {
    let allRecords: [DailyUsageRecord]
    let rangeDays: Int

    private var calendar: Calendar { .current }
    private var normalizedRangeDays: Int { max(1, rangeDays) }

    var rangeRecords: [DailyUsageRecord] {
        guard !allRecords.isEmpty else { return [] }
        let sorted = allRecords.sorted { $0.date < $1.date }
        guard let latestDate = sorted.last?.date,
              let startDate = calendar.date(byAdding: .day, value: -(normalizedRangeDays - 1), to: latestDate) else {
            return sorted
        }
        return sorted.filter { $0.date >= startDate && $0.date <= latestDate }
    }

    var totalConsumed: Int {
        rangeRecords.reduce(0) { $0 + $1.totalConsumed }
    }

    var averageConsumed: Int {
        let records = rangeRecords
        guard !records.isEmpty else { return 0 }
        return totalConsumed / records.count
    }

    var peakRecord: DailyUsageRecord? {
        rangeRecords.max { lhs, rhs in
            if lhs.totalConsumed == rhs.totalConsumed {
                return lhs.date < rhs.date
            }
            return lhs.totalConsumed < rhs.totalConsumed
        }
    }
}

