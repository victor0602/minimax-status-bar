import Foundation

enum MiniMaxAPIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(Int)
    case missingAPIKey
    case apiError(String)
}

class MiniMaxAPIService {
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

        // 调试：打印原始响应
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🔍 Raw API response: \(jsonString)")
            let path = "/tmp/minimax_raw_response.json"
            try? jsonString.write(toFile: path, atomically: true, encoding: .utf8)
        }

        let decoded = try JSONDecoder().decode(QuotaResponse.self, from: data)

        if let baseResp = decoded.baseResp, baseResp.statusCode != 0 {
            throw MiniMaxAPIError.apiError(baseResp.statusMsg)
        }

        return decoded.modelRemains.map { ModelQuota.from(raw: $0) }
    }
}
