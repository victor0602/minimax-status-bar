import Foundation
import AppKit

struct ReleaseInfo: Sendable {
    let version: String
    let downloadURL: URL
    let releaseNotes: String
}

// MARK: - Download Delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let destination: URL
    private let progressHandler: (Double) -> Void
    private let completionHandler: (Result<URL, Error>) -> Void

    init(destination: URL,
         progressHandler: @escaping (Double) -> Void,
         completionHandler: @escaping (Result<URL, Error>) -> Void) {
        self.destination = destination
        self.progressHandler = progressHandler
        self.completionHandler = completionHandler
        super.init()
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.progressHandler(progress)
        }
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: location, to: destination)
            DispatchQueue.main.async {
                self.completionHandler(.success(self.destination))
            }
        } catch {
            DispatchQueue.main.async {
                self.completionHandler(.failure(error))
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.completionHandler(.failure(error))
            }
        }
    }
}

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
            let appPath = Bundle.main.bundlePath
            NSWorkspace.shared.open(URL(fileURLWithPath: appPath))
            NSApplication.shared.terminate(nil)
        }
    }

    private func downloadFile(from url: URL, to destination: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let delegate = DownloadDelegate(
                destination: destination,
                progressHandler: { [weak self] progress in
                    self?.downloadProgress = progress
                },
                completionHandler: { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            )

            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
            self.currentSession = session

            let task = session.downloadTask(with: url)
            task.resume()
        }
    }

    func cancelDownload() {
        currentSession?.invalidateAndCancel()
        currentSession = nil
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
