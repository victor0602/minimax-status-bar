import Foundation

// MARK: - Download delegate

private final class UpdateDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let destination: URL
    private let progressHandler: (Double) -> Void
    private let completionHandler: (Result<URL, Error>) -> Void
    private let completionLock = NSLock()
    private var didInvokeCompletion = false

    init(
        destination: URL,
        progressHandler: @escaping (Double) -> Void,
        completionHandler: @escaping (Result<URL, Error>) -> Void
    ) {
        self.destination = destination
        self.progressHandler = progressHandler
        self.completionHandler = completionHandler
        super.init()
    }

    private func deliverCompletion(_ result: Result<URL, Error>) {
        completionLock.lock()
        if didInvokeCompletion {
            completionLock.unlock()
            return
        }
        didInvokeCompletion = true
        completionLock.unlock()
        DispatchQueue.main.async {
            self.completionHandler(result)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.progressHandler(progress)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: location, to: destination)
            deliverCompletion(.success(destination))
        } catch {
            deliverCompletion(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            deliverCompletion(.failure(error))
        }
    }
}

// MARK: - Public downloader

enum UpdateFileDownloader {
    /// Downloads a file to `destination` (file is replaced if it exists). `progress` and completion are delivered on the main queue.
    static func download(
        from url: URL,
        to destination: URL,
        progress: @escaping (Double) -> Void,
        sessionCreated: ((URLSession) -> Void)? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let delegate = UpdateDownloadDelegate(
                destination: destination,
                progressHandler: progress,
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
            sessionCreated?(session)

            let task = session.downloadTask(with: url)
            task.resume()
        }
    }
}
