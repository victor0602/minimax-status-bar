import Foundation

/// 离线缓存读写抽象（`QuotaState` 依赖注入，便于单测 Mock）。
@MainActor
protocol QuotaStatePersistence: AnyObject {
    func loadCachedQuota() -> (models: [ModelQuota], cachedAt: Date?)?
    func saveCachedQuota(models: [ModelQuota], cachedAt: Date)
}

@MainActor
final class UserDefaultsQuotaPersistence: QuotaStatePersistence {
    static let shared = UserDefaultsQuotaPersistence()

    private let defaults = UserDefaults.standard
    private let modelsKey = "com.openclaw.minimax.persistence.cachedModels.v1"
    private let cachedAtKey = "com.openclaw.minimax.persistence.cachedAt.v1"

    private init() {}

    func loadCachedQuota() -> (models: [ModelQuota], cachedAt: Date?)? {
        guard let data = defaults.data(forKey: modelsKey),
              !data.isEmpty else { return nil }
        let decoder = JSONDecoder()
        guard let persisted = try? decoder.decode([PersistedModelQuota].self, from: data),
              !persisted.isEmpty else { return nil }
        let models = persisted.map { $0.toModelQuota() }
        let cachedAt: Date?
        if defaults.object(forKey: cachedAtKey) != nil {
            cachedAt = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: cachedAtKey))
        } else {
            cachedAt = nil
        }
        return (models, cachedAt)
    }

    func saveCachedQuota(models: [ModelQuota], cachedAt: Date) {
        let persisted = models.map { PersistedModelQuota(from: $0) }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(persisted) else { return }
        defaults.set(data, forKey: modelsKey)
        defaults.set(cachedAt.timeIntervalSinceReferenceDate, forKey: cachedAtKey)
    }
}
