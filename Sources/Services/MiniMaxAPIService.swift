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

final class MiniMaxAPIService: APIServiceProtocol {
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
        request.timeoutInterval = 30
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let t0 = Date()
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            APIMetrics.recordFailure(message: error.localizedDescription)
            throw MiniMaxAPIError.networkError(error)
        }

        let ms = Int(Date().timeIntervalSince(t0) * 1000)

        guard let httpResponse = response as? HTTPURLResponse else {
            APIMetrics.recordFailure(message: "non-http response")
            throw MiniMaxAPIError.networkError(NSError(domain: "Unknown", code: -1))
        }

        guard httpResponse.statusCode == 200 else {
            APIMetrics.recordFailure(message: "HTTP \(httpResponse.statusCode)")
            throw MiniMaxAPIError.serverError(httpResponse.statusCode)
        }

        let decoded: QuotaResponse
        do {
            decoded = try JSONDecoder().decode(QuotaResponse.self, from: data)
        } catch {
            APIMetrics.recordFailure(message: "decode failed")
            throw MiniMaxAPIError.decodingError
        }

        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("MiniMax Status Bar [DEBUG] API raw response:")
            print(jsonString)
        }
        #endif

        if let baseResp = decoded.baseResp, baseResp.statusCode != 0 {
            APIMetrics.recordFailure(message: baseResp.statusMsg)
            throw MiniMaxAPIError.apiError(baseResp.statusMsg)
        }

        APIMetrics.recordSuccess(durationMs: ms)
        return decoded.modelRemains.map { ModelQuota.from(raw: $0) }
    }
}
