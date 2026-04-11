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

/// Token Plan「剩余次数」接口里，`current_interval_usage_count` / `current_weekly_usage_count` 表示 **剩余**（与控制台一致），不是已用。
/// 本 struct 同时保存「剩余」与由总额推算的「已用」，避免命名误导。
struct ModelQuota {
    let modelName: String
    /// 当前日/周期配额上限（次）
    let totalCount: Int
    /// 已消耗次数
    let intervalConsumedCount: Int
    /// 剩余次数（与控制台「剩余」一致）
    let remainingCount: Int
    /// 已用占总额比例 0...100（与 `remainingPercent` 互补，用于核对控制台「已用%」）
    let intervalConsumedPercent: Int
    /// 周维度上限
    let weeklyTotalCount: Int
    /// 本周已用（推算：周上限 − 周剩余）
    let weeklyConsumedCount: Int
    /// 本周剩余（与 API `current_weekly_usage_count` 同语义）
    let weeklyRemainingCount: Int
    let remainsTimeMs: Int64
    let weeklyStartTime: Date
    let weeklyEndTime: Date
    let fetchedAt: Date

    static func from(raw: ModelQuotaRaw) -> ModelQuota {
        let remainingInterval = raw.currentIntervalUsageCount
        let consumedInterval = raw.currentIntervalTotalCount - raw.currentIntervalUsageCount
        let consumedPct = raw.currentIntervalTotalCount > 0
            ? consumedInterval * 100 / raw.currentIntervalTotalCount
            : 0

        let weeklyRemaining = raw.currentWeeklyUsageCount
        let weeklyConsumed = raw.currentWeeklyTotalCount - raw.currentWeeklyUsageCount

        return ModelQuota(
            modelName: raw.modelName,
            totalCount: raw.currentIntervalTotalCount,
            intervalConsumedCount: consumedInterval,
            remainingCount: remainingInterval,
            intervalConsumedPercent: consumedPct,
            weeklyTotalCount: raw.currentWeeklyTotalCount,
            weeklyConsumedCount: weeklyConsumed,
            weeklyRemainingCount: weeklyRemaining,
            remainsTimeMs: raw.remainsTime,
            weeklyStartTime: Date(timeIntervalSince1970: TimeInterval(raw.weeklyStartTime) / 1000),
            weeklyEndTime: Date(timeIntervalSince1970: TimeInterval(raw.weeklyEndTime) / 1000),
            fetchedAt: Date()
        )
    }

    /// Remains time that decreases in real-time based on elapsed seconds since fetch
    var dynamicRemainsTimeMs: Int64 {
        let elapsed = Int64(Date().timeIntervalSince(fetchedAt) * 1000)
        return max(0, remainsTimeMs - elapsed)
    }

    var remainsTimeFormatted: String {
        let ms = dynamicRemainsTimeMs
        if ms <= 0 {
            return "即将重置"
        }
        let hours = ms / 3_600_000
        let minutes = (ms % 3_600_000) / 60_000
        let seconds = (ms % 60_000) / 1000
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

    /// Ultra-short tag for `NSStatusItem` title (heavy M2.7 users get an instant read).
    var statusBarAbbreviation: String {
        let n = modelName.lowercased()
        if n.contains("m2.7") { return "2.7·" }
        if n.contains("minimax-m") { return "M·" }
        if n.contains("hailuo") { return "V·" }
        if n.contains("speech") { return "S·" }
        if n.contains("music") { return "Mu·" }
        if n.contains("image") { return "I·" }
        return ""
    }
}
