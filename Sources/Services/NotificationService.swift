import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    private static let lowQuotaNotificationIdentifier = "com.openclaw.minimax-status-bar.lowQuota.primary"
    /// Only the **primary** model (same pick order as menu bar) triggers low-quota alerts — avoids modal spam for M2.7-first workflows.
    private var notifiedPrimaryKey: String?

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in }
    }

    /// Checks primary model quota and sends notification when low.
    ///
    /// Notification policy:
    /// - **< 10%**: Critical - send one-time notification, remember which model was notified
    /// - **10%–19%**: Recovery zone - clear the notified flag so a future <10% drop can re-alert.
    ///   This prevents the "stuck at 12%" scenario where the user never gets another alert
    ///   even after the quota eventually drops further.
    /// - **≥ 20%**: Safe zone - clear the notified flag unconditionally
    func checkAndNotify(primary: ModelQuota?) {
        guard let primary else {
            notifiedPrimaryKey = nil
            return
        }
        let key = primary.modelName
        if primary.remainingPercent < 10 {
            if notifiedPrimaryKey != key {
                notifiedPrimaryKey = key
                sendNotification(
                    title: "主力模型配额偏低",
                    body: "\(primary.displayName) 剩余 \(primary.remainingPercent)%，约 \(primary.remainsTimeFormatted) 后重置"
                )
            }
        } else if primary.remainingPercent >= 20 {
            notifiedPrimaryKey = nil
        } else {
            // 10%…19%：允许之后再次跌破 10% 时重复提醒（与原先「≥20% 才 reset」一致）
            if notifiedPrimaryKey == key {
                notifiedPrimaryKey = nil
            }
        }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: Self.lowQuotaNotificationIdentifier,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
