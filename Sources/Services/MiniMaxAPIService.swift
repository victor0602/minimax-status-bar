import Foundation

enum MiniMaxAPIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError
    case serverError(Int)
    case missingAPIKey
    case apiError(String)
}

class MiniMaxAPIService: @unchecked Sendable {
    private let apiKey: String
    private let baseURL = "https://api.minimaxi.com/v1/api/openplatform/coding_plan/remains"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func fetchQuota() async throws -> [ModelQuota] {
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

        let decoded: QuotaResponse
        do {
            decoded = try JSONDecoder().decode(QuotaResponse.self, from: data)
        } catch {
            throw MiniMaxAPIError.decodingError
        }

        if let baseResp = decoded.baseResp, baseResp.statusCode != 0 {
            throw MiniMaxAPIError.apiError(baseResp.statusMsg)
        }

        return decoded.modelRemains.map { ModelQuota.from(raw: $0) }
    }
}
