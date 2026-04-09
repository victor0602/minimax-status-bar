import Foundation

struct TokenUsage {
    let totalTokens: Int
    let usedTokens: Int
    let remainingTokens: Int
    let usagePercent: Double
    let updatedAt: Date

    var usedPercent: Double {
        return 100 - usagePercent
    }
}
