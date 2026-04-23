import Foundation

/// Validation result for API key format checks.
enum APIKeyValidationResult {
    case valid                  // Token Plan key, can be used for quota API
    case missing                // Empty or not found
    case invalidFormat          // Has prefix but too short or otherwise malformed
    case nonTokenPlanKey        // Looks like a regular API key (sk-), not a Token Plan key (sk-cp-)
}

/// Resolves MiniMax API key from environment, Keychain, OpenClaw `.env`, or `openclaw.json`.
enum APIKeyResolver {
    /// Minimum length for a valid API key (prefix + content)
    private static let minimumKeyLength = 40

    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> String {
        if let key = environment["MINIMAX_API_KEY"], !key.isEmpty {
            return key
        }

        if let key = APIKeyKeychainStore.load(), !key.isEmpty {
            return key
        }

        let home = fileManager.homeDirectoryForCurrentUser
        let envPath = home.appendingPathComponent(".openclaw/.env")
        if let content = try? String(contentsOf: envPath, encoding: .utf8),
           let key = minimaxKey(fromOpenClawEnv: content) {
            return key
        }

        let jsonPath = home.appendingPathComponent(".openclaw/openclaw.json")
        guard let data = try? Data(contentsOf: jsonPath),
              let key = minimaxKey(fromOpenClawJSONData: data), !key.isEmpty else {
            return ""
        }
        return key
    }

    /// Validates an API key for Token Plan quota API usage.
    /// - Parameter key: The raw API key string
    /// - Returns: Validation result indicating whether the key is valid for quota API calls
    static func validateForQuotaAPI(_ key: String) -> APIKeyValidationResult {
        if key.isEmpty {
            return .missing
        }

        // Check for Token Plan key format: sk-cp- prefix + minimum length
        if key.hasPrefix("sk-cp-") {
            return key.count >= minimumKeyLength ? .valid : .invalidFormat
        }

        // Check for regular API key format: sk- prefix (but not sk-cp-)
        if key.hasPrefix("sk-") {
            return key.count >= minimumKeyLength ? .nonTokenPlanKey : .invalidFormat
        }

        // Unknown format
        return .invalidFormat
    }

    /// Parses `MINIMAX_API_KEY=...` from multiline `.env` content (first non-empty match).
    static func minimaxKey(fromOpenClawEnv content: String) -> String? {
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("MINIMAX_API_KEY=") {
                var value = String(trimmed.dropFirst("MINIMAX_API_KEY=".count))
                value = value.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                if !value.isEmpty {
                    return value
                }
            }
        }
        return nil
    }

    /// Reads MiniMax key from OpenClaw `openclaw.json` payload.
    static func minimaxKey(fromOpenClawJSONData data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let models = json["models"] as? [String: Any],
           let providers = models["providers"] as? [String: Any],
           let minimax = providers["minimax"] as? [String: Any],
           let apiKey = minimax["apiKey"] as? String, !apiKey.isEmpty {
            return apiKey
        }

        if let env = json["env"] as? [String: Any],
           let apiKey = env["MINIMAX_API_KEY"] as? String, !apiKey.isEmpty {
            return apiKey
        }

        return nil
    }
}
