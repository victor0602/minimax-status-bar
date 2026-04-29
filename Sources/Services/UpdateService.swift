import Foundation

actor UpdateService {
    private let currentVersion: String
    private let githubRepo: String
    private let session: URLSession

    init(githubRepo: String = AppConfig.githubRepo, session: URLSession = .shared) {
        self.githubRepo = githubRepo
        self.session = session
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        self.currentVersion = bundleVersion.replacingOccurrences(of: "v", with: "", options: .caseInsensitive)
    }

    func checkForUpdate() async -> ReleaseInfo? {
        let urlString = "https://api.github.com/repos/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        guard let (data, _) = try? await session.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String else {
            return nil
        }

        let latestVersion = tagName.replacingOccurrences(of: "v", with: "", options: .caseInsensitive)
        guard Self.isLatestVersion(latestVersion, strictlyNewerThan: currentVersion) else {
            return nil
        }

        var downloadURL: URL?
        var checksumURL: URL?
        if let assets = json["assets"] as? [[String: Any]] {
            for asset in assets {
                if let urlString = asset["browser_download_url"] as? String,
                   let assetURL = URL(string: urlString),
                   assetURL.path.lowercased().hasSuffix(".dmg") {
                    downloadURL = assetURL
                    break
                }
            }

            if let dmgURL = downloadURL {
                checksumURL = Self.checksumAssetURL(for: dmgURL, in: assets)
            }
        }

        guard let dmgURL = downloadURL else { return nil }

        let body = json["body"] as? String ?? ""
        let expectedSHA256: String?
        if let checksumURL {
            expectedSHA256 = await fetchChecksum(from: checksumURL, matching: dmgURL.lastPathComponent)
        } else {
            expectedSHA256 = Self.sha256Checksum(in: body, matching: dmgURL.lastPathComponent)
        }

        guard let expectedSHA256 else { return nil }

        return ReleaseInfo(
            version: latestVersion,
            downloadURL: dmgURL,
            expectedSHA256: expectedSHA256,
            releaseNotes: body
        )
    }

    /// Compares dotted version strings so `2.0` and `2.0.0` are treated as the same release (no false update prompt).
    private static func isLatestVersion(_ latest: String, strictlyNewerThan current: String) -> Bool {
        let latestParts = normalizedIntParts(latest)
        let currentParts = normalizedIntParts(current)
        let count = max(latestParts.count, currentParts.count)
        let lp = latestParts + Array(repeating: 0, count: count - latestParts.count)
        let cp = currentParts + Array(repeating: 0, count: count - currentParts.count)
        for i in 0..<count {
            if lp[i] > cp[i] { return true }
            if lp[i] < cp[i] { return false }
        }
        return false
    }

    private static func normalizedIntParts(_ version: String) -> [Int] {
        version
            .replacingOccurrences(of: "v", with: "", options: .caseInsensitive)
            .split(separator: ".")
            .compactMap { Int($0) }
    }

    private static func checksumAssetURL(for dmgURL: URL, in assets: [[String: Any]]) -> URL? {
        let dmgName = dmgURL.lastPathComponent.lowercased()
        let replacementName = dmgName.replacingOccurrences(of: ".dmg", with: ".sha256")
        let acceptedNames = [
            "\(dmgName).sha256",
            "\(dmgName).sha256sum",
            replacementName
        ]

        for asset in assets {
            guard let urlString = asset["browser_download_url"] as? String,
                  let assetURL = URL(string: urlString) else { continue }
            let fileName = assetURL.lastPathComponent.lowercased()
            if acceptedNames.contains(fileName) {
                return assetURL
            }
        }

        return nil
    }

    private func fetchChecksum(from url: URL, matching fileName: String) async -> String? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        guard let (data, _) = try? await session.data(for: request),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return Self.sha256Checksum(in: text, matching: fileName)
    }

    static func sha256Checksum(in text: String, matching fileName: String? = nil) -> String? {
        let lines = text.components(separatedBy: .newlines)
        if let fileName {
            for line in lines where line.localizedCaseInsensitiveContains(fileName) {
                if let checksum = firstSHA256Hex(in: line) {
                    return checksum
                }
            }
        }

        return firstSHA256Hex(in: text)
    }

    private static func firstSHA256Hex(in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"[A-Fa-f0-9]{64}"#) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let matchRange = Range(match.range, in: text) else {
            return nil
        }
        return String(text[matchRange]).lowercased()
    }
}
