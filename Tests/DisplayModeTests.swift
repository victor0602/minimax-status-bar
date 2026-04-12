import XCTest
@testable import MiniMax_Status_Bar

final class DisplayModeTests: XCTestCase {
    func testMenuBarDisplayModeRawValues() {
        XCTAssertEqual(MenuBarDisplayMode.concise.rawValue, "concise")
        XCTAssertEqual(MenuBarDisplayMode.verbose.rawValue, "verbose")
    }

    func testFormatCountForDisplay() {
        XCTAssertEqual(ModelQuota.formatCountForDisplay(500), "500")
        XCTAssertEqual(ModelQuota.formatCountForDisplay(1500), "1.5K")
    }
}
