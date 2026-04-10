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
    @Published var lastError: String?
    @Published var lastCheckedAt: Date?

    private var downloadTask: URLSessionDownloadTask?

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
        lastError = nil

        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("MiniMaxStatusBar.dmg")

        try? FileManager.default.removeItem(at: destinationURL)

        Task {
            var request = URLRequest(url: release.downloadURL)
            request.timeoutInterval = 300

            do {
                let (tempURL, response) = try await URLSession.shared.download(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    await MainActor.run {
                        self.lastError = "下载失败，请检查网络"
                        self.isDownloading = false
                    }
                    return
                }

                try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                await MainActor.run {
                    self.downloadProgress = 1.0
                    self.isDownloading = false
                }

                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "更新已下载"
                    alert.informativeText = "请将 MiniMax Status Bar 拖入 Applications 文件夹完成更新，然后重启 app。"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "确定")
                    alert.runModal()

                    NSWorkspace.shared.open(destinationURL)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        NSApplication.shared.terminate(nil)
                    }
                }

            } catch {
                await MainActor.run {
                    self.lastError = "下载失败: \(error.localizedDescription)"
                    self.isDownloading = false
                }
            }
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadProgress = 0.0
    }
}
