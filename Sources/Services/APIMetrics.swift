import Foundation

/// 最近一次配额请求耗时（用于设置页展示与排查）。
enum APIMetrics {
    private static let lock = NSLock()
    private static var _lastFetchDurationMs: Int = 0
    private static var _lastFetchAt: Date?
    private static var _lastErrorDescription: String?

    static var lastFetchDurationMs: Int {
        lock.lock()
        defer { lock.unlock() }
        return _lastFetchDurationMs
    }

    static var lastFetchAt: Date? {
        lock.lock()
        defer { lock.unlock() }
        return _lastFetchAt
    }

    static var lastErrorDescription: String? {
        lock.lock()
        defer { lock.unlock() }
        return _lastErrorDescription
    }

    static func recordSuccess(durationMs: Int) {
        lock.lock()
        _lastFetchDurationMs = durationMs
        _lastFetchAt = Date()
        _lastErrorDescription = nil
        lock.unlock()
    }

    static func recordFailure(message: String) {
        lock.lock()
        _lastErrorDescription = message
        lock.unlock()
    }
}
