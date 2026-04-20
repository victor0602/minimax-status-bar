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
        if name.contains("coding-plan-search") {
            // 联网搜索能力，归入文本能力分组
            return .text
        } else if name.contains("coding-plan-vlm") {
            // 图像识别/视觉理解能力，归入图像分组
            return .image
        } else if name.contains("lyrics_generation") {
            // 歌词创作能力，归入音乐分组
            return .music
        } else if name.contains("minimax-m") {
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

/// 原始 JSON。`current_interval_usage_count` = 本周期剩余次数，`current_weekly_usage_count` = 本周剩余次数。
/// 已用次数由 total − remaining 推算。
struct ModelQuotaRaw: Codable {
    let modelName: String
    let currentIntervalTotalCount: Int
    /// 周期内剩余次数（JSON：`current_interval_usage_count`）
    let currentIntervalRemainingCount: Int
    let currentWeeklyTotalCount: Int
    /// 本周剩余次数（JSON：`current_weekly_usage_count`）
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

/// 展示用模型：`ModelQuotaRaw` 已从 JSON 字段名解耦，周期/周维度的「已用」由 `total − 剩余` 推算。
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
        // API 直接返回剩余次数，已用 = total - remaining
        let remainingInterval = raw.currentIntervalRemainingCount
        let consumedInterval = raw.currentIntervalTotalCount - raw.currentIntervalRemainingCount

        // 计算已用百分比，处理边界情况
        let consumedPct: Int
        if raw.currentIntervalTotalCount > 0 {
            let rawPercent = consumedInterval * 100 / raw.currentIntervalTotalCount
            // 边界处理：如果有消耗但百分比四舍五入为0，显示为1%
            consumedPct = consumedInterval > 0 && rawPercent == 0 ? 1 : rawPercent
        } else {
            consumedPct = 0
        }

        let weeklyRemaining = raw.currentWeeklyRemainingCount
        let weeklyConsumed = raw.currentWeeklyTotalCount - raw.currentWeeklyRemainingCount

        #if DEBUG
        print("[MiniMax] \(raw.modelName): total=\(raw.currentIntervalTotalCount), remaining=\(remainingInterval), consumed=\(consumedInterval), consumedPct=\(consumedPct)%")
        #endif

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

    /// 菜单栏 verbose 后缀：与面板「剩余/总额」一致，用分组整数避免 K 舍入与百分比矛盾。
    var formattedRemainingCountShort: String {
        Self.formatCountForQuotaDetail(remainingCount)
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

    /// 配额明细用分组整数，避免 `formatCountForDisplay` 的 1 位 K 舍入把 29,951 与 30,000 都显示成「30.0K」，
    /// 从而与 `remainingPercent`（按精确 remaining/total 整数除法）不一致。
    private static let quotaDetailFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    static func formatCountForQuotaDetail(_ num: Int) -> String {
        quotaDetailFormatter.string(from: NSNumber(value: num)) ?? "\(num)"
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
        case let n where n.contains("coding-plan-search"):
            return "联网搜索"
        case let n where n.contains("coding-plan-vlm"):
            return "图像识别"
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
        case let n where n.contains("lyrics_generation"):
            return modelName  // 歌词创作显示原模型名称
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
        let rawPercent = remainingCount * 100 / totalCount
        // 边界处理：只有当 remaining 在 (0, total) 区间且四舍五入后为 100 时才 cap 为 99
        // remaining == total（即 0% 已用）→ 正确显示 100%
        if remainingCount > 0 && remainingCount < totalCount && rawPercent >= 100 {
            return 99
        }
        return rawPercent
    }

    /// 确保与 consumedPercent 互补为 100%，解决取整导致的"加起来不是 100%"问题
    /// 例如: consumed=1, remaining=99 (都四舍五入)，但逻辑上应该 0+100 或 1+99
    var remainingPercentForDisplay: Int {
        // 直接使用剩余量计算百分比，而不是 100 - 已用率
        // 因为小数取整会导致 0% + 100% = 100% 看起来正确，但实际已用 103/30000 剩余应该是 ~34%
        return remainingPercent
    }

    /// Ultra-short tag for `NSStatusItem` title (heavy M2.7 users get an instant read).
    /// 注意：歌词创作(lyrics_generation)显示原模型名称，不使用缩写
    var statusBarAbbreviation: String {
        let n = modelName.lowercased()
        if n.contains("m2.7") { return "2.7·" }
        if n.contains("minimax-m") { return "M·" }
        if n.contains("hailuo") { return "V·" }
        if n.contains("speech") { return "S·" }
        if n.contains("lyrics_generation") { return "" }  // 歌词创作显示原名称
        if n.contains("music") { return "Mu·" }
        if n.contains("image") { return "I·" }
        return ""
    }
}
