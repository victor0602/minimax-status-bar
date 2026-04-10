import Foundation

// MARK: - Model Category

enum ModelCategory: String, CaseIterable {
    case text = "Text"
    case speech = "Speech"
    case video = "Video"
    case music = "Music"
    case image = "Image"
    case unknown = "Unknown"

    var priority: Int {
        switch self {
        case .text: return 0
        case .speech: return 1
        case .video: return 2
        case .music: return 3
        case .image: return 4
        case .unknown: return 5
        }
    }

    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .speech: return "waveform"
        case .video: return "film"
        case .music: return "music.note"
        case .image: return "photo"
        case .unknown: return "questionmark.circle"
        }
    }
}

extension ModelQuota {
    var category: ModelCategory {
        let name = modelName.lowercased()
        if name.contains("minimax-m") {
            return .text
        } else if name.contains("hailuo") {
            return .video
        } else if name.contains("speech") {
            return .speech
        } else if name.contains("music") {
            return .music
        } else if name.contains("image") {
            return .image
        }
        return .unknown
    }
}

// MARK: - Raw API Response

struct QuotaResponse: Codable {
    let baseResp: BaseResp?
    let modelRemains: [ModelQuotaRaw]

    enum CodingKeys: String, CodingKey {
        case baseResp = "base_resp"
        case modelRemains = "model_remains"
    }
}

struct BaseResp: Codable {
    let statusCode: Int
    let statusMsg: String

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case statusMsg = "status_msg"
    }
}

struct ModelQuotaRaw: Codable {
    let modelName: String
    let currentIntervalTotalCount: Int
    let currentIntervalUsageCount: Int
    let currentWeeklyTotalCount: Int
    let currentWeeklyUsageCount: Int
    let remainsTime: Int64
    let weeklyStartTime: Int64
    let weeklyEndTime: Int64

    enum CodingKeys: String, CodingKey {
        case modelName = "model_name"
        case currentIntervalTotalCount = "current_interval_total_count"
        case currentIntervalUsageCount = "current_interval_usage_count"
        case currentWeeklyTotalCount = "current_weekly_total_count"
        case currentWeeklyUsageCount = "current_weekly_usage_count"
        case remainsTime = "remains_time"
        case weeklyStartTime = "weekly_start_time"
        case weeklyEndTime = "weekly_end_time"
    }
}

// MARK: - Processed Model

struct ModelQuota {
    let modelName: String
    let totalCount: Int
    let usageCount: Int
    let remainingCount: Int
    let usedPercent: Int
    let weeklyTotal: Int
    let weeklyUsage: Int
    let weeklyRemaining: Int
    let remainsTimeMs: Int64
    let weeklyStartTime: Date
    let weeklyEndTime: Date

    static func from(raw: ModelQuotaRaw) -> ModelQuota {
        // API 字段 usage_count 实际表示剩余次数（而非已用）
        let remaining = raw.currentIntervalUsageCount
        let used = raw.currentIntervalTotalCount - raw.currentIntervalUsageCount
        let usedPct = raw.currentIntervalTotalCount > 0
            ? used * 100 / raw.currentIntervalTotalCount
            : 0

        return ModelQuota(
            modelName: raw.modelName,
            totalCount: raw.currentIntervalTotalCount,
            usageCount: used,
            remainingCount: remaining,
            usedPercent: usedPct,
            weeklyTotal: raw.currentWeeklyTotalCount,
            weeklyUsage: raw.currentWeeklyTotalCount - raw.currentWeeklyUsageCount,
            weeklyRemaining: raw.currentWeeklyUsageCount,
            remainsTimeMs: raw.remainsTime,
            weeklyStartTime: Date(timeIntervalSince1970: TimeInterval(raw.weeklyStartTime) / 1000),
            weeklyEndTime: Date(timeIntervalSince1970: TimeInterval(raw.weeklyEndTime) / 1000)
        )
    }

    var remainsTimeFormatted: String {
        if remainsTimeMs <= 0 {
            return "即将重置"
        }
        let hours = remainsTimeMs / 3600000
        let minutes = (remainsTimeMs % 3600000) / 60000
        let seconds = (remainsTimeMs % 60000) / 1000
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }

    var displayName: String {
        switch modelName.lowercased() {
        case let n where n.contains("minimax-m"):
            return "MiniMax-M"
        case let n where n.contains("speech-hd"):
            return "Text to Speech HD"
        case let n where n.contains("hailuo-2.3-fast"):
            return "Hailuo-2.3-Fast"
        case let n where n.contains("hailuo-2.3"):
            return "Hailuo-2.3"
        case let n where n.contains("music-2.5"):
            return "Music 2.5"
        case let n where n.contains("music-2.6"):
            return "Music 2.6"
        case let n where n.contains("music-cover"):
            return "Music Cover"
        case let n where n.contains("music"):
            return "Music"
        case let n where n.contains("image-01"):
            return "Image 01"
        case let n where n.contains("image"):
            return "Image"
        default:
            return modelName
        }
    }

    var remainingPercent: Int {
        guard totalCount > 0 else { return 0 }
        return remainingCount * 100 / totalCount
    }
}
