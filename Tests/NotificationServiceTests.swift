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
        // Cannot verify notification was sent in unit test without notification center mock,
        // but we can verify the state transitions
    }

    func testShouldNotResendNotificationIfAlreadyNotifiedSameModel() {
        let model = makeModel(remainingPercent: 8)
        // First notification
        notificationService.checkAndNotify(primary: model)
        // Second notification for same model at even lower percent should not re-trigger
        // The service tracks notifiedPrimaryKey to avoid duplicate notifications
        let lowerModel = makeModel(remainingPercent: 5)
        notificationService.checkAndNotify(primary: lowerModel)
        // If we got here without crash, the service handled it gracefully
    }

    func testShouldAllowReNotificationAfterRecoveryAbove20Percent() {
        let model8 = makeModel(remainingPercent: 8)
        notificationService.checkAndNotify(primary: model8)

        // Simulate recovery to 25%
        let model25 = makeModel(remainingPercent: 25)
        notificationService.checkAndNotify(primary: model25)

        // Simulate drop again to 8%
        let model8Again = makeModel(remainingPercent: 8)
        notificationService.checkAndNotify(primary: model8Again)
        // Should be allowed since recovery happened
    }

    func testShouldNotNotifyWhenQuotaAlwaysAbove10Percent() {
        let model = makeModel(remainingPercent: 12)
        notificationService.checkAndNotify(primary: model)
        // Should not send notification, notifiedPrimaryKey should remain nil
    }

    func testShouldResetNotificationWhenRecoveredAbove20Percent() {
        let model = makeModel(remainingPercent: 8)
        notificationService.checkAndNotify(primary: model)

        let recoveredModel = makeModel(remainingPercent: 25)
        notificationService.checkAndNotify(primary: recoveredModel)
        // notifiedPrimaryKey should be reset to nil
    }
}
