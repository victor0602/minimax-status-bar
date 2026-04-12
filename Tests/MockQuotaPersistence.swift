import Foundation
@testable import MiniMax_Status_Bar

@MainActor
final class MockQuotaPersistence: QuotaStatePersistence {
    var saved: ([ModelQuota], Date)?
    var loadReturn: ([ModelQuota], Date?)?

    func loadCachedQuota() -> (models: [ModelQuota], cachedAt: Date?)? {
        loadReturn
    }

    func saveCachedQuota(models: [ModelQuota], cachedAt: Date) {
        saved = (models, cachedAt)
    }
}
