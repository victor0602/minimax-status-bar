import Foundation

struct APIStats {
    var totalCalls: Int = 0
    var callsThisMinute: Int = 0
    var successCount: Int = 0
    var failureCount: Int = 0
    var avgResponseTime: Double = 0

    var errorRate: Double {
        return totalCalls > 0 ? Double(failureCount) / Double(totalCalls) : 0
    }
}
