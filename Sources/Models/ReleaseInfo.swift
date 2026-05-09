import Foundation
import CryptoKit
import Security

struct ReleaseInfo: Sendable {
    let version: String
    let downloadURL: URL
    let expectedSHA256: String
    let releaseNotes: String

    /// 预期文件名（用于完整性校验）
    var expectedFileName: String {
        downloadURL.lastPathComponent
    }

    /// 预期 bundle identifier（用于完整性校验）
    var expectedBundleIdentifier: String {
        "com.openclaw.minimax-status-bar"
    }

    /// 下载域名（用于完整性校验）
    var downloadHost: String {
        downloadURL.host ?? ""
    }
}

// MARK: - Update Integrity Verification

/// 更新包完整性校验结果
enum UpdateIntegrityResult {
    case valid
    case invalidDomain(String)
    case invalidFileName(String)
    case missingChecksum
    case checksumMismatch(expected: String, actual: String)
    case invalidBundleIdentifier(String)
    case invalidVersion(String, String)
    case invalidTeamIdentifier(String, String)
    case invalidCodeSignature
    case verificationFailed(String)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .valid:
            return nil
        case .invalidDomain(let host):
            return "下载来源不可信（非 github.com）：\(host)"
        case .invalidFileName(let name):
            return "文件名不安全：\(name)"
        case .missingChecksum:
            return "缺少 SHA256 校验值"
        case .checksumMismatch(let expected, let actual):
            return "SHA256 不匹配：预期 \(expected)，实际 \(actual)"
        case .invalidBundleIdentifier(let id):
            return "Bundle ID 不匹配：\(id)"
        case .invalidVersion(let expected, let actual):
            return "版本号不匹配：预期 \(expected)，实际 \(actual)"
        case .invalidTeamIdentifier(let expected, let actual):
            return "签名 Team ID 不匹配：预期 \(expected)，实际 \(actual)"
        case .invalidCodeSignature:
            return "下载应用代码签名无效"
        case .verificationFailed(let reason):
            return "校验失败：\(reason)"
        }
    }
}

/// 更新包完整性校验器
enum UpdateIntegrityChecker {
    private static func createStaticCode(bundlePath: String) -> SecStaticCode? {
        var code: SecStaticCode?
        let status = SecStaticCodeCreateWithPath(URL(fileURLWithPath: bundlePath) as CFURL, [], &code)
        guard status == errSecSuccess else { return nil }
        return code
    }

    private static func normalizedVersionParts(_ version: String) -> [Int] {
        version
            .replacingOccurrences(of: "v", with: "", options: .caseInsensitive)
            .split(separator: ".")
            .compactMap { Int($0) }
    }

    private static func versionsEquivalent(_ lhs: String, _ rhs: String) -> Bool {
        let lp = normalizedVersionParts(lhs)
        let rp = normalizedVersionParts(rhs)
        let count = max(lp.count, rp.count)
        let a = lp + Array(repeating: 0, count: count - lp.count)
        let b = rp + Array(repeating: 0, count: count - rp.count)
        return a == b
    }

    private static func copyTeamIdentifier(from bundlePath: String) -> String? {
        guard let staticCode = createStaticCode(bundlePath: bundlePath) else { return nil }
        var signingInfoRef: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        let status = SecCodeCopySigningInformation(staticCode, flags, &signingInfoRef)
        guard status == errSecSuccess,
              let signingInfo = signingInfoRef as? [String: Any],
              let teamID = signingInfo[kSecCodeInfoTeamIdentifier as String] as? String,
              !teamID.isEmpty else {
            return nil
        }
        return teamID
    }

    private static func hasValidCodeSignature(bundlePath: String) -> Bool {
        guard let staticCode = createStaticCode(bundlePath: bundlePath) else { return false }
        return SecStaticCodeCheckValidity(staticCode, SecCSFlags(), nil) == errSecSuccess
    }
    /// 校验下载文件：来源、文件名和 SHA256 必须全部匹配。
    static func verifyDownloadedFile(release: ReleaseInfo, fileURL: URL) -> UpdateIntegrityResult {
        // 1. 校验下载域名（只允许 github.com）
        let downloadHost = release.downloadHost.lowercased()
        guard downloadHost == "github.com" else {
            return .invalidDomain(release.downloadHost)
        }

        // 2. 校验文件名后缀（必须是 .dmg）
        let fileName = release.expectedFileName.lowercased()
        guard fileName.hasSuffix(".dmg") else {
            return .invalidFileName(release.expectedFileName)
        }

        let expectedSHA256 = release.expectedSHA256.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard expectedSHA256.range(of: #"^[a-f0-9]{64}$"#, options: .regularExpression) != nil else {
            return .missingChecksum
        }

        do {
            let actualSHA256 = try sha256Hex(forFileAt: fileURL)
            guard actualSHA256 == expectedSHA256 else {
                return .checksumMismatch(expected: expectedSHA256, actual: actualSHA256)
            }
        } catch {
            return .verificationFailed(error.localizedDescription)
        }

        return .valid
    }

    /// 校验版本一致性：ReleaseInfo.version 必须与下载的 DMG bundle 版本一致
    static func verifyMountedBundle(release: ReleaseInfo, downloadedBundlePath: String) -> UpdateIntegrityResult {
        guard hasValidCodeSignature(bundlePath: downloadedBundlePath) else {
            return .invalidCodeSignature
        }

        // 1. 校验 bundle identifier
        guard let bundle = Bundle(path: downloadedBundlePath),
              bundle.bundleIdentifier == release.expectedBundleIdentifier else {
            let actualId = Bundle(path: downloadedBundlePath)?.bundleIdentifier ?? "nil"
            return .invalidBundleIdentifier(actualId)
        }

        // 2. 校验 Team Identifier（若当前运行应用可解析 Team ID）
        let currentBundlePath = Bundle.main.bundlePath
        if let expectedTeamID = copyTeamIdentifier(from: currentBundlePath),
           let downloadedTeamID = copyTeamIdentifier(from: downloadedBundlePath),
           expectedTeamID != downloadedTeamID {
            return .invalidTeamIdentifier(expectedTeamID, downloadedTeamID)
        }

        // 3. 校验版本号（语义等价：2.0 == 2.0.0）
        guard let bundleVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
              versionsEquivalent(bundleVersion, release.version) else {
            let actualVersion = Bundle(path: downloadedBundlePath)?
                .infoDictionary?["CFBundleShortVersionString"] as? String ?? "nil"
            return .invalidVersion(release.version, actualVersion)
        }

        return .valid
    }

    static func verify(
        release: ReleaseInfo,
        downloadedFileURL: URL,
        downloadedBundlePath: String
    ) -> UpdateIntegrityResult {
        let fileResult = verifyDownloadedFile(release: release, fileURL: downloadedFileURL)
        guard fileResult.isValid else { return fileResult }
        return verifyMountedBundle(release: release, downloadedBundlePath: downloadedBundlePath)
    }

    static func sha256Hex(forFileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let data = handle.readData(ofLength: 1024 * 1024)
            if data.isEmpty { break }
            hasher.update(data: data)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
