import AppKit
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        NotificationService.shared.registerUpdateNotificationCategory()
        statusBarController = StatusBarController()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard response.notification.request.content.categoryIdentifier == NotificationService.updateCategoryIdentifier else {
            return
        }
        switch response.actionIdentifier {
        case NotificationService.updateActionLater:
            break
        case NotificationService.updateActionInstall, UNNotificationDefaultActionIdentifier:
            let version = response.notification.request.content.userInfo["version"] as? String
            Task { @MainActor in
                UpdateState.shared.beginInstallFromNotification(expectedVersion: version)
            }
        default:
            break
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // cleanup
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
