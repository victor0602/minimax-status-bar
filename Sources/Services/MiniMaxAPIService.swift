import Foundation

struct MiniMaxTokenResponse: Codable {
    let usagePercent: Double
    let modelRemains: ModelRemains

    enum CodingKeys: String, CodingKey {
        case usagePercent = "usage_percent"
        case modelRemains = "model_remains"
    }
}

struct ModelRemains: Codable {
    let chat: Int?
}

enum MiniMaxAPIError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int)
    case missingAPIKey
}

class MiniMaxAPIService {
    private let apiKey: String
    private let baseURL = "https://www.minimax.io/v1/api/openplatform/coding_plan/remains"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func fetchTokenUsage() async throws -> TokenUsage {
        guard !apiKey.isEmpty else {
            throw MiniMaxAPIError.missingAPIKey
        }

        guard let url = URL(string: baseURL) else {
            throw MiniMaxAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MiniMaxAPIError.networkError(NSError(domain: "Unknown", code: -1))
        }

        guard httpResponse.statusCode == 200 else {
            throw MiniMaxAPIError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(MiniMaxTokenResponse.self, from: data)

        // ⚠️ API BUG WORKAROUND: usage_percent means remaining, not used
        // TODO: revert when MiniMax fixes the API response
        let usedPercent = 100 - apiResponse.usagePercent
        let remainingTokens = apiResponse.modelRemains.chat ?? 0
        let totalTokens = apiResponse.usagePercent > 0 ? Int(Double(remainingTokens) / apiResponse.usagePercent * 100) : 0
        let usedTokens = totalTokens - remainingTokens

        return TokenUsage(
            totalTokens: totalTokens,
            usedTokens: max(0, usedTokens),
            remainingTokens: remainingTokens,
            usagePercent: apiResponse.usagePercent,
            updatedAt: Date()
        )
    }
}
