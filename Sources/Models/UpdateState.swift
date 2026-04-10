import Foundation
import AppKit

struct ReleaseInfo: Sendable {
    let version: String
    let downloadURL: URL
    let releaseNotes: String
}

final class UpdateState: ObservableObject {
    static let shared = UpdateState()

    @Published var latestRelease: ReleaseInfo?
    @Published var isChecking: Bool = false
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var installPhase: String = ""
    @Published var lastError: String?
    @Published var lastCheckedAt: Date?

    private var progressTimer: Timer?

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
            try await downloadFile(from: release.downloadURL, to: tmpDMG)
        } catch {
            self.lastError = "下载失败: \(error.localizedDescription)"
            self.isDownloading = false
            return
        }

        self.installPhase = "安装中"

        let mountPoint = "/tmp/MiniMaxStatusBarMount"
        try? FileManager.default.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)

        let mountResult = shell("hdiutil attach '\(tmpDMG.path)' -mountpoint '\(mountPoint)' -nobrowse -quiet")
        guard mountResult == 0 else {
            self.lastError = "挂载更新包失败"
            self.isDownloading = false
            return
        }

        let mountedApp = "\(mountPoint)/MiniMax Status Bar.app"
        let targetApp = Bundle.main.bundlePath

        var copyResult = shell("cp -Rf '\(mountedApp)' '\(targetApp)'")

        shell("hdiutil detach '\(mountPoint)' -quiet")
        try? FileManager.default.removeItem(at: tmpDMG)

        if copyResult != 0 {
            let script = """
                do shell script "cp -Rf '\(mountedApp)' '\(targetApp)'" with administrator privileges
            """
            var errorDict: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&errorDict)
            if errorDict != nil {
                self.lastError = "安装失败，请检查权限"
                self.isDownloading = false
                return
            }
            copyResult = 0
        }

        guard copyResult == 0 else {
            self.lastError = "复制文件失败"
            self.isDownloading = false
            return
        }

        self.installPhase = "重启中"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/MiniMax Status Bar.app"))
            NSApplication.shared.terminate(nil)
        }
    }

    private func downloadFile(from url: URL, to destination: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)

            let task = session.downloadTask(with: url) { [weak self] tempURL, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let tempURL = tempURL else {
                    continuation.resume(throwing: NSError(domain: "UpdateError", code: -1))
                    return
                }
                do {
                    try? FileManager.default.removeItem(at: destination)
                    try FileManager.default.copyItem(at: tempURL, to: destination)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            // Poll progress every 0.1s
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self, weak task] timer in
                guard let self = self, self.isDownloading, let task = task else {
                    timer.invalidate()
                    return
                }
                let total = task.countOfBytesExpectedToReceive
                if total > 0 {
                    let received = Double(task.countOfBytesReceived)
                    DispatchQueue.main.async {
                        self.downloadProgress = received / Double(total)
                    }
                }
                if task.state == .completed || task.state == .canceling {
                    timer.invalidate()
                }
            }

            task.resume()
        }
    }

    func cancelDownload() {
        isDownloading = false
        downloadProgress = 0.0
        installPhase = ""
    }

    @discardableResult
    private func shell(_ command: String) -> Int32 {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", command]
        task.launch()
        task.waitUntilExit()
        return task.terminationStatus
    }
}
