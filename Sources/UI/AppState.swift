import Foundation

class AppState: ObservableObject {
    @Published var tokenUsage: TokenUsage?
    @Published var apiStats: APIStats = APIStats()
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    @Published var isDetailExpanded: Bool = false
}
