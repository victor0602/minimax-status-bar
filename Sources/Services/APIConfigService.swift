import Foundation

/// API 请求配置
struct APIRequestConfig {
    /// 请求超时时间（秒）
    var timeoutInterval: TimeInterval
    /// 是否启用请求 ID（DEBUG 下自动开启）
    var enableRequestID: Bool

    static let `default` = APIRequestConfig(
        timeoutInterval: 30,
        enableRequestID: false
    )

    #if DEBUG
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

    /// 当前 API 配置
    var currentConfig: APIRequestConfig {
        get {
            let timeout = defaults.double(forKey: timeoutKey)
            let enableID = defaults.bool(forKey: enableRequestIDKey)
            return APIRequestConfig(
                timeoutInterval: timeout > 0 ? timeout : 30,
                enableRequestID: enableID
            )
        }
        set {
            defaults.set(newValue.timeoutInterval, forKey: timeoutKey)
            defaults.set(newValue.enableRequestID, forKey: enableRequestIDKey)
        }
    }

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

    /// 生成唯一请求 ID（UUID 前 8 位）
    static func generateRequestID() -> String {
        UUID().uuidString.prefix(8).uppercased()
    }
}