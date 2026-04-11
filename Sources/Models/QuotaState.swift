import Foundation

@MainActor
class QuotaState: ObservableObject {
    @Published var models: [ModelQuota] = []
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    @Published var lastUpdatedAt: Date?
    /// When set, show onboarding instead of treating the situation as a generic load error.
    @Published var setupReason: SetupReason?

    var hasData: Bool { !models.isEmpty }

    var primaryModel: ModelQuota? {
        models.first { $0.modelName.lowercased().contains("m2.7") }
            ?? models.first { $0.modelName.lowercased().contains("minimax-m") }
            ?? models.first
    }
}
