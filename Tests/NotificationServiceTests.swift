import XCTest
@testable import MiniMax_Status_Bar

final class NotificationServiceTests: XCTestCase {
    var notificationService: NotificationService!

    override func setUp() {
        super.setUp()
        notificationService = NotificationService.shared
    }

    override func tearDown() {
        notificationService = nil
        super.tearDown()
    }

    /// Helper to create a ModelQuota with given remaining percent
    /// API 返回 remaining，所以 remaining = total * percent / 100
    private func makeModel(name: String = "MiniMax-M2.7", remainingPercent: Int, remainingMs: Int64 = 3600000) -> ModelQuota {
        let total = 100
        let remaining = total * remainingPercent / 100
        return ModelQuota.from(raw: ModelQuotaRaw(
            modelName: name,
            currentIntervalTotalCount: total,
            currentIntervalRemainingCount: remaining,
            currentWeeklyTotalCount: 1000,
            currentWeeklyRemainingCount: 400,
            remainsTime: remainingMs,
            weeklyStartTime: 0,
            weeklyEndTime: 86400000
        ))
    }

    func testShouldNotifyWhenQuotaDropsBelow10Percent() {
        let model = makeModel(remainingPercent: 8)
        notificationService.checkAndNotify(primary: model)
    }

    func testShouldNotResendNotificationIfAlreadyNotifiedSameModel() {
        let model = makeModel(remainingPercent: 8)
        notificationService.checkAndNotify(primary: model)
        let lowerModel = makeModel(remainingPercent: 5)
        notificationService.checkAndNotify(primary: lowerModel)
    }

    func testShouldAllowReNotificationAfterRecoveryAbove20Percent() {
        let model8 = makeModel(remainingPercent: 8)
        notificationService.checkAndNotify(primary: model8)
        let model25 = makeModel(remainingPercent: 25)
        notificationService.checkAndNotify(primary: model25)
        let model8Again = makeModel(remainingPercent: 8)
        notificationService.checkAndNotify(primary: model8Again)
    }

    func testShouldNotNotifyWhenQuotaAlwaysAbove10Percent() {
        let model = makeModel(remainingPercent: 12)
        notificationService.checkAndNotify(primary: model)
    }

    func testShouldResetNotificationWhenRecoveredAbove20Percent() {
        let model = makeModel(remainingPercent: 8)
        notificationService.checkAndNotify(primary: model)
        let recoveredModel = makeModel(remainingPercent: 25)
        notificationService.checkAndNotify(primary: recoveredModel)
    }
}
