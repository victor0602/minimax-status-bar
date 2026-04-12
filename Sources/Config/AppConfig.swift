import Foundation

struct AppConfig: Sendable {
    /// GitHub repository owner/repo for update checking
    static let githubRepo = "victor0602/minimax-status-bar"
}

/// UserDefaults / `@AppStorage` keys shared across AppKit and SwiftUI
enum AppStorageKeys {
    /// When true, a detected release triggers in-app download + install without an extra click (still may prompt for admin to copy into `/Applications`).
    static let prefersAutomaticUpdateInstall = "prefersAutomaticUpdateInstall"
}
