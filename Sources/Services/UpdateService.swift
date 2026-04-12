import Foundation

actor UpdateService {
    private let currentVersion: String
    private let githubRepo: String

    init(githubRepo: String = AppConfig.githubRepo) {
        self.githubRepo = githubRepo
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        self.currentVersion = bundleVersion.replacingOccurrences(of: "v", with: "", options: .caseInsensitive)
    }

    func checkForUpdate() async -> ReleaseInfo? {
        let urlString = "https://api.github.com/repos/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String else {
            return nil
        }

        let latestVersion = tagName.replacingOccurrences(of: "v", with: "", options: .caseInsensitive)
        guard Self.isLatestVersion(latestVersion, strictlyNewerThan: currentVersion) else {
            return nil
        }

        var downloadURL: URL?
        if let assets = json["assets"] as? [[String: Any]] {
            for asset in assets {
                if let urlString = asset["browser_download_url"] as? String,
                   urlString.lowercased().contains(".dmg") {
                    downloadURL = URL(string: urlString)
                    break
                }
            }
        }

        guard let dmgURL = downloadURL else { return nil }

        let body = json["body"] as? String ?? ""

        return ReleaseInfo(version: latestVersion, downloadURL: dmgURL, releaseNotes: body)
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
}
