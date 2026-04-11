import XCTest
@testable import MiniMax_Status_Bar

final class UpdateServiceTests: XCTestCase {
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
}
