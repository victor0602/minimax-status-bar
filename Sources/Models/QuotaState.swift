import Foundation

@MainActor
class QuotaState: ObservableObject {
    @Published var models: [ModelQuota] = []
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    @Published var lastUpdatedAt: Date?
    /// When set, show onboarding instead of treating the situation as a generic load error.
    @Published var setupReason: SetupReason?

    /// Cached models from the last successful API fetch (for offline display)
    @Published var cachedModels: [ModelQuota] = []
    /// Timestamp of the last successful API fetch
    @Published var cachedAt: Date?

    var hasData: Bool { !models.isEmpty }
    /// Whether cached data is available for offline display
    var hasCachedData: Bool { !cachedModels.isEmpty }

    /// Primary model selection priority: M2.7 → minimax-m prefix → first available model
    var primaryModel: ModelQuota? {
        models.first { $0.modelName.lowercased().contains("m2.7") }
            ?? models.first { $0.modelName.lowercased().contains("minimax-m") }
            ?? models.first
    }

    /// Primary model based on cached data (used when API fails but cache exists)
    var cachedPrimaryModel: ModelQuota? {
        cachedModels.first { $0.modelName.lowercased().contains("m2.7") }
            ?? cachedModels.first { $0.modelName.lowercased().contains("minimax-m") }
            ?? cachedModels.first
    }
}
