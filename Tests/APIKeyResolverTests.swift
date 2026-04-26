import XCTest
@testable import MiniMax_Status_Bar

final class APIKeyResolverTests: XCTestCase {
    func testResolveUsesEnvironmentVariableFirst() {
        let key = APIKeyResolver.resolve(
            environment: ["MINIMAX_API_KEY": "sk-cp-from-env"],
            keychainLoad: { nil },
            keychainSave: { _ in true }
        )
        XCTAssertEqual(key, "sk-cp-from-env")
    }

    func testResolveSyncsEnvironmentKeyToKeychain() {
        var savedKey: String?
        let resolved = APIKeyResolver.resolve(
            environment: ["MINIMAX_API_KEY": "sk-cp-sync-me"],
            keychainLoad: { nil },
            keychainSave: { key in
                savedKey = key
                return true
            }
        )
        XCTAssertEqual(resolved, "sk-cp-sync-me")
        XCTAssertEqual(savedKey, "sk-cp-sync-me")
    }

    func testMinimaxKeyFromOpenClawEnvStripsQuotes() {
        let content = """
        # comment
        MINIMAX_API_KEY="sk-cp-quoted"
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

// MARK: - APIKeyValidator Tests

extension APIKeyResolverTests {
    /// Generates a key with given prefix and total length
    private func makeKey(prefix: String, totalLength: Int) -> String {
        let suffixLength = totalLength - prefix.count
        let suffix = String(repeating: "x", count: max(0, suffixLength))
        return prefix + suffix
    }

    func testValidateForQuotaAPI_EmptyString_ReturnsMissing() {
        XCTAssertEqual(APIKeyResolver.validateForQuotaAPI(""), .missing)
    }

    func testValidateForQuotaAPI_ValidTokenPlanKey_ReturnsValid() {
        // Token Plan key: sk-cp- prefix + at least 40 chars total
        let key = makeKey(prefix: "sk-cp-", totalLength: 40)
        XCTAssertEqual(APIKeyResolver.validateForQuotaAPI(key), .valid)
    }

    func testValidateForQuotaAPI_ShortTokenPlanKey_ReturnsInvalidFormat() {
        // Token Plan key that's too short
        let key = "sk-cp-abc"
        XCTAssertEqual(APIKeyResolver.validateForQuotaAPI(key), .invalidFormat)
    }

    func testValidateForQuotaAPI_RegularAPIKey_ReturnsNonTokenPlanKey() {
        // Regular API key (sk- but not sk-cp-) with sufficient length
        let key = makeKey(prefix: "sk-", totalLength: 40)
        XCTAssertEqual(APIKeyResolver.validateForQuotaAPI(key), .nonTokenPlanKey)
    }

    func testValidateForQuotaAPI_RegularAPIKeyTooShort_ReturnsInvalidFormat() {
        let key = "sk-short"
        XCTAssertEqual(APIKeyResolver.validateForQuotaAPI(key), .invalidFormat)
    }

    func testValidateForQuotaAPI_NoPrefix_ReturnsInvalidFormat() {
        XCTAssertEqual(APIKeyResolver.validateForQuotaAPI("some-random-key"), .invalidFormat)
    }

    func testValidateForQuotaAPI_ExactlyMinimumLength_ReturnsValid() {
        // Exactly 40 chars with sk-cp- prefix
        let key = makeKey(prefix: "sk-cp-", totalLength: 40)
        XCTAssertEqual(APIKeyResolver.validateForQuotaAPI(key), .valid)
    }

    func testValidateForQuotaAPI_OneCharShort_ReturnsInvalid() {
        // 39 chars with sk-cp- prefix (6 prefix + 33 chars = 39)
        let key = makeKey(prefix: "sk-cp-", totalLength: 39)
        XCTAssertEqual(APIKeyResolver.validateForQuotaAPI(key), .invalidFormat)
    }
}
