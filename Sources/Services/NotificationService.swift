import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    private static let lowQuotaNotificationIdentifier = "com.openclaw.minimax-status-bar.lowQuota.primary"
    private static let updateNotificationIdentifier = "com.openclaw.minimax-status-bar.updateAvailable"

    /// Category + actions for version updates (must match `AppDelegate` handling).
    static let updateCategoryIdentifier = "UPDATE_AVAILABLE"
    static let updateActionInstall = "UPDATE_INSTALL"
    static let updateActionLater = "UPDATE_LATER"

    /// Only the **primary** model (same pick order as menu bar) triggers low-quota alerts — avoids modal spam for M2.7-first workflows.
    private var notifiedPrimaryKey: String?

    private init() {}

    /// Registers actionable update category; safe to call repeatedly.
    func registerUpdateNotificationCategory() {
        let install = UNNotificationAction(
            identifier: Self.updateActionInstall,
            title: "立即更新",
            options: [.foreground]
        )
        let later = UNNotificationAction(
            identifier: Self.updateActionLater,
            title: "稍后",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.updateCategoryIdentifier,
            actions: [install, later],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func requestPermission() {
        registerUpdateNotificationCategory()
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in }
    }

    /// Posts at most one update banner per version per 24h (re-check still shows ⬆ in the menu bar).
    func offerUpdateAvailable(_ release: ReleaseInfo) {
        let key = "updateNotificationSent.\(release.version)"
        if let last = UserDefaults.standard.object(forKey: key) as? Date,
           Date().timeIntervalSince(last) < 24 * 3600 {
            return
        }
        UserDefaults.standard.set(Date(), forKey: key)

        let content = UNMutableNotificationContent()
        content.title = "MiniMax Status Bar 可更新"
        content.body = "新版本 v\(release.version) 已发布。点「立即更新」将自动下载并替换当前应用（与菜单内更新相同）。"
        content.sound = .default
        content.categoryIdentifier = Self.updateCategoryIdentifier
        content.userInfo = ["version": release.version]

        let request = UNNotificationRequest(
            identifier: Self.updateNotificationIdentifier,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Checks primary model quota and sends notification when low.
    ///
    /// Notification policy (三段区间业务含义):
    /// - **< 10%**: 临界告警区 — 配额告急，发送一次性通知并记录已通知的模型 key
    /// - **10%–19%**: 恢复观察区 — 既不发送通知也不重置标志位。设计意图：配额停在此区间时，
    ///   若继续下跌仍能触发 <10% 的告警；若回升则进入安全区重置标志，避免"卡在 12%"导致
    ///   用户永远收不到后续低配额提醒
    /// - **≥ 20%**: 安全区 — 无条件清除已通知标志，配额回到充足状态
    ///
    /// Notification policy:
    /// - **< 10%**: Critical - send one-time notification, remember which model was notified
    /// - **10%–19%**: Recovery zone - clear the notified flag so a future <10% drop can re-alert.
    ///   This prevents the "stuck at 12%" scenario where the user never gets another alert
    ///   even after the quota eventually drops further.
    /// - **≥ 20%**: Safe zone - clear the notified flag unconditionally
    func checkAndNotify(primary: ModelQuota?) {
        guard UserDefaults.standard.object(forKey: AppStorageKeys.lowQuotaNotificationEnabled) as? Bool ?? true else {
            return
        }
        guard let primary else {
            notifiedPrimaryKey = nil
            return
        }
        let threshold = (UserDefaults.standard.object(forKey: AppStorageKeys.lowQuotaThresholdPercent) as? Int)
            .map { min(50, max(1, $0)) } ?? 10
        let recovery = (UserDefaults.standard.object(forKey: AppStorageKeys.lowQuotaRecoverPercent) as? Int)
            .map { min(99, max(threshold + 1, $0)) } ?? max(threshold + 1, 20)

        let key = primary.modelName
        if primary.remainingPercent < threshold {
            if notifiedPrimaryKey != key {
                notifiedPrimaryKey = key
                sendNotification(
                    title: "主力模型配额偏低",
                    body: "\(primary.displayName) 剩余 \(primary.remainingPercent)%，约 \(primary.remainsTimeFormatted) 后重置"
                )
            }
        } else if primary.remainingPercent >= recovery {
            notifiedPrimaryKey = nil
        } else {
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
