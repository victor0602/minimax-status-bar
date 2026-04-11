import Foundation

/// Resolves MiniMax API key from environment, OpenClaw `.env`, or `openclaw.json` (same priority as UI copy).
enum APIKeyResolver {
    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> String {
        if let key = environment["MINIMAX_API_KEY"], !key.isEmpty {
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
