import Foundation

struct AppConfig: Sendable {
    /// GitHub repository owner/repo for update checking
    static let githubRepo = "victor0602/minimax-status-bar"
}

/// UserDefaults / `@AppStorage` keys shared across AppKit and SwiftUI
enum AppStorageKeys {
    static let prefersAutomaticUpdateInstall = "prefersAutomaticUpdateInstall"
    /// Polling interval in seconds: 30 / 60 / 120 / 300
    static let refreshIntervalSeconds = "refreshIntervalSeconds"
    /// `concise` | `verbose` — menu bar title suffix (remaining count)
    static let menuBarDisplayMode = "menuBarDisplayMode"
    static let lowQuotaNotificationEnabled = "lowQuotaNotificationEnabled"
    static let lowQuotaThresholdPercent = "lowQuotaThresholdPercent"
    /// When remaining ≥ this, low-quota notify latch resets (default 20)
    static let lowQuotaRecoverPercent = "lowQuotaRecoverPercent"
    /// Multi-account: use stored profiles instead of env-only resolution
    static let multiAccountEnabled = "multiAccountEnabled"
    static let activeAccountId = "activeAccountId"
    static let storedAccountsJSON = "storedAccountsJSON.v1"
}

extension Notification.Name {
    /// Posted when settings change polling / display so `StatusBarController` can reschedule.
    static let minimaxPreferencesDidChange = Notification.Name("com.openclaw.minimax.preferencesDidChange")
}

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case concise
    case verbose
    var id: String { rawValue }
    var title: String {
        switch self {
        case .concise: return "简洁"
        case .verbose: return "详细（含剩余次数）"
        }
    }
}

