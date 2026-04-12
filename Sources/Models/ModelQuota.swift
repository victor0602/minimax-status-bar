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

/// 原始 JSON。注意：接口字段名含 `usage_count`，但语义是 **剩余次数**（与控制台「剩余」一致），不是「已用」。
struct ModelQuotaRaw: Codable {
    let modelName: String
    let currentIntervalTotalCount: Int
    /// 周期内 **剩余** 次数（JSON：`current_interval_usage_count`，勿按字面当成已用）
    let currentIntervalRemainingCount: Int
    let currentWeeklyTotalCount: Int
    /// 本周 **剩余** 次数（JSON：`current_weekly_usage_count`）
    let currentWeeklyRemainingCount: Int
    let remainsTime: Int64
    let weeklyStartTime: Int64
    let weeklyEndTime: Int64

    enum CodingKeys: String, CodingKey {
        case modelName = "model_name"
        case currentIntervalTotalCount = "current_interval_total_count"
        case currentIntervalRemainingCount = "current_interval_usage_count"
        case currentWeeklyTotalCount = "current_weekly_total_count"
        case currentWeeklyRemainingCount = "current_weekly_usage_count"
        case remainsTime = "remains_time"
        case weeklyStartTime = "weekly_start_time"
        case weeklyEndTime = "weekly_end_time"
    }
}

// MARK: - Processed Model

/// 展示用模型：`ModelQuotaRaw` 已从 JSON 字段名解耦，周期/周维度的「已用」一律由 `total − 剩余` 推算。
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
    /// 本周剩余（与原始 JSON `current_weekly_usage_count` 同数值）
    let weeklyRemainingCount: Int
    let remainsTimeMs: Int64
    let weeklyStartTime: Date
    let weeklyEndTime: Date
    let fetchedAt: Date

    static func from(raw: ModelQuotaRaw) -> ModelQuota {
        let remainingInterval = raw.currentIntervalRemainingCount
        let consumedInterval = raw.currentIntervalTotalCount - raw.currentIntervalRemainingCount
        let consumedPct = raw.currentIntervalTotalCount > 0
            ? consumedInterval * 100 / raw.currentIntervalTotalCount
            : 0

        let weeklyRemaining = raw.currentWeeklyRemainingCount
        let weeklyConsumed = raw.currentWeeklyTotalCount - raw.currentWeeklyRemainingCount

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

    /// Full initializer for persistence restore / tests.
    init(
        modelName: String,
        totalCount: Int,
        intervalConsumedCount: Int,
        remainingCount: Int,
        intervalConsumedPercent: Int,
        weeklyTotalCount: Int,
        weeklyConsumedCount: Int,
        weeklyRemainingCount: Int,
        remainsTimeMs: Int64,
        weeklyStartTime: Date,
        weeklyEndTime: Date,
        fetchedAt: Date
    ) {
        self.modelName = modelName
        self.totalCount = totalCount
        self.intervalConsumedCount = intervalConsumedCount
        self.remainingCount = remainingCount
        self.intervalConsumedPercent = intervalConsumedPercent
        self.weeklyTotalCount = weeklyTotalCount
        self.weeklyConsumedCount = weeklyConsumedCount
        self.weeklyRemainingCount = weeklyRemainingCount
        self.remainsTimeMs = remainsTimeMs
        self.weeklyStartTime = weeklyStartTime
        self.weeklyEndTime = weeklyEndTime
        self.fetchedAt = fetchedAt
    }

    /// Compact remaining count for menu bar detailed mode (matches row formatting).
    var formattedRemainingCountShort: String {
        Self.formatCountForDisplay(remainingCount)
    }

    static func formatCountForDisplay(_ num: Int) -> String {
        if num >= 1_000_000_000 {
            return String(format: "%.1fB", Double(num) / 1_000_000_000)
        }
        if num >= 1_000_000 {
            return String(format: "%.1fM", Double(num) / 1_000_000)
        }
        if num >= 1_000 {
            return String(format: "%.1fK", Double(num) / 1_000)
        }
        return "\(num)"
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
        case let n where n.contains("m2.7"):
            return "MiniMax M2.7"
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

    /// 确保与 consumedPercent 互补为 100%，解决取整导致的"加起来不是 100%"问题
    /// 例如: consumed=1, remaining=99 (都四舍五入)，但逻辑上应该 0+100 或 1+99
    var remainingPercentForDisplay: Int {
        return 100 - intervalConsumedPercent
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
