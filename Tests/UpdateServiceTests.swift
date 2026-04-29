import XCTest
@testable import MiniMax_Status_Bar

final class UpdateServiceTests: XCTestCase {
    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        MockURLProtocol.errorHandler = nil
        super.tearDown()
    }

    /// Helper function to compare semantic versions.
    /// Returns true if `current` is less than `latest` (i.e., update is needed).
    private func needsUpdate(current: String, latest: String) -> Bool {
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }

        // Pad shorter array with zeros for comparison
        let maxCount = max(currentParts.count, latestParts.count)
        let currentPadded = currentParts + Array(repeating: 0, count: maxCount - currentParts.count)
        let latestPadded = latestParts + Array(repeating: 0, count: maxCount - latestParts.count)

        for i in 0..<maxCount {
            if currentPadded[i] < latestPadded[i] {
                return true // current < latest, update needed
            } else if currentPadded[i] > latestPadded[i] {
                return false // current > latest, no update needed
            }
        }
        return false // equal versions, no update needed
    }

    func testNeedsUpdateWhenNewerVersionAvailable() {
        XCTAssertTrue(needsUpdate(current: "1.1.1", latest: "1.1.2"))
        XCTAssertTrue(needsUpdate(current: "1.1.1", latest: "1.2.0"))
        XCTAssertTrue(needsUpdate(current: "1.1.1", latest: "2.0.0"))
        XCTAssertTrue(needsUpdate(current: "1.2.0", latest: "2.0.0"))
    }

    func testDoesNotNeedUpdateWhenVersionsEqual() {
        XCTAssertFalse(needsUpdate(current: "1.1.1", latest: "1.1.1"))
        XCTAssertFalse(needsUpdate(current: "2.0.0", latest: "2.0.0"))
    }

    func testDoesNotNeedUpdateWhenCurrentIsNewerThanLatest() {
        // User has a pre-release or patched version beyond the latest release
        XCTAssertFalse(needsUpdate(current: "1.1.2", latest: "1.1.1"))
        XCTAssertFalse(needsUpdate(current: "1.2.0", latest: "1.1.2"))
        XCTAssertFalse(needsUpdate(current: "2.0.0", latest: "1.9.9"))
    }

    func testNeedsUpdateFromMajorToMajor() {
        XCTAssertTrue(needsUpdate(current: "1.2.0", latest: "2.0.0"))
        XCTAssertTrue(needsUpdate(current: "2.0.0", latest: "3.0.0"))
    }

    func testVersionComparisonWithDifferentComponentCounts() {
        XCTAssertTrue(needsUpdate(current: "1.1", latest: "1.1.1"))
        XCTAssertTrue(needsUpdate(current: "1", latest: "1.1.0"))
        XCTAssertFalse(needsUpdate(current: "1.1", latest: "1.1"))
    }

    /// Matches `UpdateService` release check: app `2.0` must not prompt when GitHub tag is `v2.0.0`.
    func testTwoZeroEqualsTwoZeroZero() {
        XCTAssertFalse(needsUpdate(current: "2.0", latest: "2.0.0"))
        XCTAssertFalse(needsUpdate(current: "2.0.0", latest: "2.0"))
    }

    func testTwoZeroPatchOneIsNewer() {
        XCTAssertTrue(needsUpdate(current: "2.0", latest: "2.0.1"))
    }

    func testCheckForUpdateReadsSHA256Asset() async {
        let expectedSHA256 = String(repeating: "a", count: 64)
        let session = makeSession()

        MockURLProtocol.requestHandler = { req in
            let url = req.url!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/releases/latest") {
                let payload = """
                {
                  "tag_name": "v99.0.0",
                  "body": "",
                  "assets": [
                    { "browser_download_url": "https://github.com/openclaw/minimax-status-bar/releases/download/v99.0.0/MiniMaxStatusBar.dmg" },
                    { "browser_download_url": "https://github.com/openclaw/minimax-status-bar/releases/download/v99.0.0/MiniMaxStatusBar.dmg.sha256" }
                  ]
                }
                """.data(using: .utf8)!
                return (response, payload)
            }
            return (response, Data("\(expectedSHA256)  MiniMaxStatusBar.dmg\n".utf8))
        }

        let service = UpdateService(githubRepo: "openclaw/minimax-status-bar", session: session)
        let release = await service.checkForUpdate()

        XCTAssertEqual(release?.expectedSHA256, expectedSHA256)
        XCTAssertEqual(release?.downloadURL.lastPathComponent, "MiniMaxStatusBar.dmg")
    }

    func testCheckForUpdateRejectsReleaseWithoutSHA256() async {
        let session = makeSession()

        MockURLProtocol.requestHandler = { req in
            let url = req.url!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let payload = """
            {
              "tag_name": "v99.0.0",
              "body": "",
              "assets": [
                { "browser_download_url": "https://github.com/openclaw/minimax-status-bar/releases/download/v99.0.0/MiniMaxStatusBar.dmg" }
              ]
            }
            """.data(using: .utf8)!
            return (response, payload)
        }

        let service = UpdateService(githubRepo: "openclaw/minimax-status-bar", session: session)
        let release = await service.checkForUpdate()

        XCTAssertNil(release)
    }

    func testSHA256ChecksumExtractsMatchingDmgLine() {
        let expected = String(repeating: "b", count: 64)
        let other = String(repeating: "c", count: 64)
        let text = """
        \(other)  Other.dmg
        \(expected)  MiniMaxStatusBar.dmg
        """

        XCTAssertEqual(
            UpdateService.sha256Checksum(in: text, matching: "MiniMaxStatusBar.dmg"),
            expected
        )
    }

    func testVerifyDownloadedFileRejectsChecksumMismatch() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiniMaxStatusBar-\(UUID().uuidString).dmg")
        try Data("not the expected dmg".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let release = ReleaseInfo(
            version: "99.0.0",
            downloadURL: URL(string: "https://github.com/openclaw/minimax-status-bar/releases/download/v99.0.0/MiniMaxStatusBar.dmg")!,
            expectedSHA256: String(repeating: "d", count: 64),
            releaseNotes: ""
        )

        let result = UpdateIntegrityChecker.verifyDownloadedFile(release: release, fileURL: fileURL)
        guard case .checksumMismatch = result else {
            XCTFail("expected checksumMismatch, got \(result)")
            return
        }
    }
}
