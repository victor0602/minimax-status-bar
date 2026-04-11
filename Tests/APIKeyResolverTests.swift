import XCTest
@testable import MiniMax_Status_Bar

final class APIKeyResolverTests: XCTestCase {
    func testResolveUsesEnvironmentVariableFirst() {
        let key = APIKeyResolver.resolve(environment: ["MINIMAX_API_KEY": "sk-cp-from-env"])
        XCTAssertEqual(key, "sk-cp-from-env")
    }

    func testMinimaxKeyFromOpenClawEnvStripsQuotes() {
        let content = """
        # comment
        MINIMAX_API_KEY=\"sk-cp-quoted\"
        """
        XCTAssertEqual(APIKeyResolver.minimaxKey(fromOpenClawEnv: content), "sk-cp-quoted")
    }

    func testMinimaxKeyFromOpenClawJSONPrefersModelsProvidersPath() {
        let json = """
        {"models":{"providers":{"minimax":{"apiKey":"sk-json-1"}}},"env":{"MINIMAX_API_KEY":"sk-env-json"}}
        """.data(using: .utf8)!
        XCTAssertEqual(APIKeyResolver.minimaxKey(fromOpenClawJSONData: json), "sk-json-1")
    }

    func testMinimaxKeyFromOpenClawJSONFallsBackToEnvSection() {
        let json = """
        {"env":{"MINIMAX_API_KEY":"sk-only-env"}}
        """.data(using: .utf8)!
        XCTAssertEqual(APIKeyResolver.minimaxKey(fromOpenClawJSONData: json), "sk-only-env")
    }
}
