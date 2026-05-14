import Foundation

/// API 请求配置
struct APIRequestConfig: Sendable {
    /// 请求超时时间（秒）
    var timeoutInterval: TimeInterval
    /// 是否启用请求 ID（DEBUG 下自动开启，RELEASE 可通过设置启用）
    var enableRequestID: Bool

    /// 默认配置（RELEASE 模式）
    static let `default` = APIRequestConfig(
        timeoutInterval: 30,
        enableRequestID: false
    )

    #if DEBUG
    /// DEBUG 配置（请求 ID 默认开启，便于排查问题）
    static let debug = APIRequestConfig(
        timeoutInterval: 30,
        enableRequestID: true
    )
    #endif
}

/// API 配置服务（UserDefaults 存储）
final class APIConfigService {
    static let shared = APIConfigService()

    private let defaults = UserDefaults.standard

    /// 超时时间存储键
    private let timeoutKey = "APITimeoutInterval"

    /// 请求 ID 存储键
    private let enableRequestIDKey = "APIEnableRequestID"

    private init() {}

    /// 超时时间（秒）
    var timeoutInterval: TimeInterval {
        get {
            let value = defaults.double(forKey: timeoutKey)
            return value > 0 ? value : 30
        }
        set {
            defaults.set(newValue, forKey: timeoutKey)
        }
    }

    /// 是否启用请求 ID
    var enableRequestID: Bool {
        get {
            defaults.bool(forKey: enableRequestIDKey)
        }
        set {
            defaults.set(newValue, forKey: enableRequestIDKey)
        }
    }

    /// 可选的超时时间选项（秒）
    static let timeoutOptions: [TimeInterval] = [10, 15, 30, 60, 120]

    /// 生成唯一请求 ID
    /// - Description: 格式为 `{短时间戳}-{UUID前8位}`，例如 `A1B2-3C4D5E6F`
    /// - Purpose: 便于在日志和 API 网关中追踪请求生命周期
    /// - Usage: DEBUG 下自动注入，RELEASE 下可通过 `enableRequestID` 配置开启
    static func generateRequestID() -> String {
        let timestamp = String(Int(Date().timeIntervalSince1970) % 10000, radix: 16).uppercased()
        let uuid = UUID().uuidString.prefix(8).uppercased()
        return "\(timestamp)-\(uuid)"
    }
}