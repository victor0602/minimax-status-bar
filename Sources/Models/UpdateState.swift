import AppKit
import Foundation

// MARK: - UpdateState

final class UpdateState: ObservableObject {
    static let shared = UpdateState()

    @Published var latestRelease: ReleaseInfo?
    @Published var isChecking: Bool = false
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var installPhase: String = ""
    @Published var lastError: String?
    @Published var lastCheckedAt: Date?

    private var currentSession: URLSession?

    private init() {}

    @MainActor
    func checkForUpdate() async {
        isChecking = true
        defer { isChecking = false }

        let service = UpdateService()
        latestRelease = await service.checkForUpdate()
        lastCheckedAt = Date()
    }

    @MainActor
    func downloadAndInstall(_ release: ReleaseInfo) {
        isDownloading = true
        downloadProgress = 0.0
        installPhase = "下载中"
        lastError = nil

        Task {
            await performFullUpdate(release: release)
        }
    }

    @MainActor
    private func performFullUpdate(release: ReleaseInfo) async {
        let tmpDMG = FileManager.default.temporaryDirectory.appendingPathComponent("MiniMaxStatusBarUpdate.dmg")
        try? FileManager.default.removeItem(at: tmpDMG)

        do {
            try await UpdateFileDownloader.download(
                from: release.downloadURL,
                to: tmpDMG,
                progress: { [weak self] value in
                    self?.downloadProgress = value
                },
                sessionCreated: { [weak self] session in
                    DispatchQueue.main.async {
                        self?.currentSession = session
                    }
                }
            )
        } catch {
            lastError = "下载失败: \(error.localizedDescription)"
            isDownloading = false
            return
        }

        installPhase = "安装中"

        do {
            try ReleaseDMGInstaller.install(
                dmgURL: tmpDMG,
                mountPoint: "/tmp/MiniMaxStatusBarMount",
                mountedAppName: "MiniMax Status Bar.app",
                targetBundlePath: Bundle.main.bundlePath
            )
        } catch ReleaseInstallError.mountFailed {
            lastError = "挂载更新包失败"
            isDownloading = false
            return
        } catch {
            lastError = "安装失败，请检查权限"
            isDownloading = false
            return
        }

        installPhase = "重启中"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let appPath = Bundle.main.bundlePath
            NSWorkspace.shared.open(URL(fileURLWithPath: appPath))
            NSApplication.shared.terminate(nil)
        }
    }

    func cancelDownload() {
        currentSession?.invalidateAndCancel()
        currentSession = nil
        isDownloading = false
        downloadProgress = 0.0
        installPhase = ""
    }

    /// Resolves `ReleaseInfo` (refreshing from GitHub if needed) and starts the in-app DMG install flow. Used from notification actions and shortcuts.
    @MainActor
    func beginInstallFromNotification(expectedVersion: String?) {
        Task { @MainActor in
            if let r = latestRelease, expectedVersion == nil || r.version == expectedVersion {
                downloadAndInstall(r)
                return
            }
            await checkForUpdate()
            guard let r = latestRelease else { return }
            if let expected = expectedVersion, r.version != expected { return }
            downloadAndInstall(r)
        }
    }
}
