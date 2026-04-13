import Foundation

@MainActor
class QuotaState: ObservableObject {
    @Published var models: [ModelQuota] = []
    @Published var isLoading: Bool = false
    @Published var lastError: AppError?
    @Published var lastUpdatedAt: Date?
    @Published var setupReason: SetupReason?

    @Published var cachedModels: [ModelQuota] = []
    @Published var cachedAt: Date?

    private let persistence: QuotaStatePersistence

    var hasData: Bool { !models.isEmpty }
    var hasCachedData: Bool { !cachedModels.isEmpty }

    // primaryModel 选取优先级说明：
    // 1. M2.7 模型优先（最常用的主力模型）
    // 2. 其次是 minimax-m 前缀的模型
    // 3. 若以上都没有，返回数组中任意第一个模型（兜底）
    var primaryModel: ModelQuota? {
        models.first { $0.modelName.lowercased().contains("m2.7") }
            ?? models.first { $0.modelName.lowercased().contains("minimax-m") }
            ?? models.first
    }

    var cachedPrimaryModel: ModelQuota? {
        cachedModels.first { $0.modelName.lowercased().contains("m2.7") }
            ?? cachedModels.first { $0.modelName.lowercased().contains("minimax-m") }
            ?? cachedModels.first
    }

    init(persistence: QuotaStatePersistence = UserDefaultsQuotaPersistence()) {
        self.persistence = persistence
        if let (loaded, at) = persistence.loadCachedQuota() {
            cachedModels = loaded
            cachedAt = at
        }
    }

    /// Successful API response: updates live + disk cache.
    func commitSuccessfulFetch(models: [ModelQuota]) {
        self.models = models
        lastUpdatedAt = Date()
        lastError = nil
        setupReason = nil
        cachedModels = models
        let now = Date()
        cachedAt = now
        persistence.saveCachedQuota(models: models, cachedAt: now)
    }
}
