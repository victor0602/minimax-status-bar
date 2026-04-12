import Foundation

/// Token Plan 配额拉取抽象，便于单元测试注入 Mock（见 `MiniMaxAPIService` 实现）。
protocol APIServiceProtocol: AnyObject {
    func fetchQuota() async throws -> [ModelQuota]
}
