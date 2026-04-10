import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    private var notifiedModels: Set<String> = []

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in }
    }

    func checkAndNotify(models: [ModelQuota]) {
        for model in models {
            let key = model.modelName
            if model.remainingPercent < 10 && !notifiedModels.contains(key) {
                notifiedModels.insert(key)
                sendNotification(
                    title: "MiniMax 配额不足",
                    body: "\(model.displayName) 剩余 \(model.remainingPercent)%，请注意使用量"
                )
            }
            if model.remainingPercent >= 20 {
                notifiedModels.remove(key)
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
