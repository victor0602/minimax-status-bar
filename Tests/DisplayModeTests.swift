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

    /// 1 位 K 舍入会把 29,951 与 30,000 都显示成「30.0K」，与按精确整数算的 99% 剩余矛盾；明细格式应区分二者。
    func testQuotaDetailFormatDoesNotCollapseNearTotal() {
        XCTAssertEqual(ModelQuota.formatCountForDisplay(29_951), ModelQuota.formatCountForDisplay(30_000))
        XCTAssertNotEqual(ModelQuota.formatCountForQuotaDetail(29_951), ModelQuota.formatCountForQuotaDetail(30_000))
    }
}
