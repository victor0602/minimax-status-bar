import Foundation

/// API Key 服务：负责从环境变量 / OpenClaw 配置中解析并校验 Token Plan Key。
///
/// 说明：历史上该能力叫 `APIKeyResolver`；为统一命名对外提供 `APIKeyService`，内部复用解析实现。
enum APIKeyService {
    static func resolve() -> String {
        APIKeyResolver.resolve()
    }

    static func validateForQuotaAPI(_ key: String) -> APIKeyValidationResult {
        APIKeyResolver.validateForQuotaAPI(key)
    }

    @discardableResult
    static func saveToKeychain(_ key: String) -> Bool {
        APIKeyKeychainStore.save(key)
    }
}

