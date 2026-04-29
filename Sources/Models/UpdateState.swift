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
    private var isUpdateInstalling: Bool = false

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
        guard !isUpdateInstalling else { return }
        isUpdateInstalling = true
        isDownloading = true
        downloadProgress = 0.0
        installPhase = "下载中"
        lastError = nil

        Task {
            await performFullUpdate(release: release)
            isUpdateInstalling = false
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
                },
                onDownloadComplete: { [weak self] in
                    DispatchQueue.main.async {
                        self?.currentSession?.invalidateAndCancel()
                        self?.currentSession = nil
                    }
                }
            )
        } catch {
            lastError = "下载失败: \(error.localizedDescription)"
            isDownloading = false
            currentSession?.invalidateAndCancel()
            currentSession = nil
            return
        }

        // 完整性校验
        installPhase = "验证中"
        let downloadedFileResult = UpdateIntegrityChecker.verifyDownloadedFile(release: release, fileURL: tmpDMG)
        guard downloadedFileResult.isValid else {
            lastError = "更新包校验失败：\(downloadedFileResult.errorDescription ?? "未知错误")"
            isDownloading = false
            try? FileManager.default.removeItem(at: tmpDMG)
            return
        }

        let mountPoint = "/tmp/MiniMaxStatusBarMount.\(UUID().uuidString)"
        let mountedBundleResult = runMountAndVerify(release: release, dmgPath: tmpDMG.path, mountPoint: mountPoint)

        if mountedBundleResult.isValid {
            installPhase = "安装中"
            do {
                try ReleaseDMGInstaller.install(
                    dmgURL: tmpDMG,
                    mountPoint: mountPoint,
                    mountedAppName: "MiniMax Status Bar.app",
                    targetBundlePath: Bundle.main.bundlePath
                )
            } catch ReleaseInstallError.mountFailed {
                lastError = "挂载更新包失败"
                isDownloading = false
                cleanupMountPoint(mountPoint)
                return
            } catch {
                lastError = "安装失败，请检查权限"
                isDownloading = false
                cleanupMountPoint(mountPoint)
                return
            }
        } else {
            lastError = "更新包校验失败：\(mountedBundleResult.errorDescription ?? "未知错误")"
            isDownloading = false
            cleanupMountPoint(mountPoint)
            return
        }

        cleanupMountPoint(mountPoint)
        installPhase = "重启中"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let appPath = Bundle.main.bundlePath
            NSWorkspace.shared.open(URL(fileURLWithPath: appPath))
            NSApplication.shared.terminate(nil)
        }
    }

    private func runMountAndVerify(release: ReleaseInfo, dmgPath: String, mountPoint: String) -> UpdateIntegrityResult {
        let hdiutil = "/usr/bin/hdiutil"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: hdiutil)
        process.arguments = ["attach", dmgPath, "-mountpoint", mountPoint, "-nobrowse", "-quiet"]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .verificationFailed(error.localizedDescription)
        }

        guard process.terminationStatus == 0 else {
            return .verificationFailed("挂载更新包失败")
        }

        defer {
            _ = run(executable: hdiutil, arguments: ["detach", mountPoint, "-quiet"])
        }

        let mountedAppPath = (mountPoint as NSString).appendingPathComponent("MiniMax Status Bar.app")
        let result = UpdateIntegrityChecker.verifyMountedBundle(release: release, downloadedBundlePath: mountedAppPath)

        if !result.isValid {
            #if DEBUG
            print("MiniMax Status Bar [DEBUG] Update integrity check failed: \(result.errorDescription ?? "unknown")")
            #endif
        }

        return result
    }

    private func run(executable: String, arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }

    private func cleanupMountPoint(_ mountPoint: String) {
        _ = run(executable: "/usr/bin/hdiutil", arguments: ["detach", mountPoint, "-quiet"])
        try? FileManager.default.removeItem(atPath: mountPoint)
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
