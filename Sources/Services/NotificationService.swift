import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    /// Only the **primary** model (same pick order as menu bar) triggers low-quota alerts — avoids modal spam for M2.7-first workflows.
    private var notifiedPrimaryKey: String?

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in }
    }

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
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
