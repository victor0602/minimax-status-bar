import AppKit
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusBarController: StatusBarController?
    private var settingsWindowController: NSWindowController?
    private var localKeyDownMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        NotificationService.shared.registerUpdateNotificationCategory()
        statusBarController = StatusBarController()

        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(.command),
                  event.charactersIgnoringModifiers == "," else {
                return event
            }
            Task { @MainActor in
                self?.openSettingsWindow()
            }
            return nil
        }
    }

    @MainActor
    func openSettingsWindow(tab: Int? = nil) {
        if settingsWindowController == nil {
            let root = SettingsView(defaultTabIndex: tab)
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: hosting)
            window.title = "MiniMax Status Bar 设置"
            window.setContentSize(NSSize(width: 680, height: 520))
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            settingsWindowController = NSWindowController(window: window)
        } else if let hosting = settingsWindowController?.contentViewController as? NSHostingController<SettingsView> {
            hosting.rootView = SettingsView(defaultTabIndex: tab)
        }
        settingsWindowController?.showWindow(nil)
        if let window = settingsWindowController?.window {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
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
        if let monitor = localKeyDownMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyDownMonitor = nil
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
