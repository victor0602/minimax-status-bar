import AppKit
import Foundation

enum ReleaseInstallError: Error {
    case mountFailed
    case copyFailed
}

/// Mounts a DMG, replaces the app bundle at `targetBundlePath`, then detaches and removes the DMG.
///
/// **Why not `cp` or `ditto` straight into the existing `.app`?** Copying a bundle *into* an existing
/// bundle path merges/nests. Even `ditto` into an existing directory updates files but can leave
/// **removed/renamed files from a prior release** inside the old bundle, which can break cross-version
/// updates.
///
/// **Strategy (in order):**
/// 1. `ditto` the mounted app to a **sibling** staging bundle, then `FileManager.replaceItemAt` to
///    swap the **entire** bundle in one step (no merge residue).
/// 2. `rsync -a --delete` to sync the mounted bundle *into* the target so the target tree exactly
///    matches the source (including deletions) — in case replace fails.
/// 3. Same `rsync` with administrator privileges.
enum ReleaseDMGInstaller {
    private static let hdiutil = "/usr/bin/hdiutil"
    private static let ditto = "/usr/bin/ditto"
    private static let rsync = "/usr/bin/rsync"

    static func install(
        dmgURL: URL,
        mountPoint: String,
        mountedAppName: String,
        targetBundlePath: String,
        fileManager: FileManager = .default
    ) throws {
        try? fileManager.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)

        guard run(executable: hdiutil, arguments: ["attach", dmgURL.path, "-mountpoint", mountPoint, "-nobrowse", "-quiet"]) == 0 else {
            throw ReleaseInstallError.mountFailed
        }

        defer {
            _ = run(executable: hdiutil, arguments: ["detach", mountPoint, "-quiet"])
            try? fileManager.removeItem(at: dmgURL)
        }

        let mountedApp = (mountPoint as NSString).appendingPathComponent(mountedAppName)
        if installByStagingDittoAndReplace(
            mountedApp: mountedApp,
            targetBundlePath: targetBundlePath,
            fileManager: fileManager
        ) {
            return
        }

        if runRsyncInPlace(mountedApp: mountedApp, targetBundlePath: targetBundlePath) == 0 {
            return
        }

        if runRsyncWithAdministrator(mountedApp: mountedApp, targetBundlePath: targetBundlePath) {
            return
        }

        throw ReleaseInstallError.copyFailed
    }

    /// `ditto` a full tree next to the target, then atomically replace the **whole** bundle.
    /// Also exercised by `ReleaseDMGInstallerTests` (not DMG E2E; same-volume temp bundles).
    @discardableResult
    static func installByStagingDittoAndReplace(
        mountedApp: String,
        targetBundlePath: String,
        fileManager: FileManager
    ) -> Bool {
        let targetURL = URL(fileURLWithPath: targetBundlePath, isDirectory: true)
        let parent = targetURL.deletingLastPathComponent()
        let stagingURL = parent.appendingPathComponent(".MiniMaxStatusBar-Staging.\(UUID().uuidString).app", isDirectory: true)

        try? fileManager.removeItem(at: stagingURL)
        if run(executable: ditto, arguments: [mountedApp, stagingURL.path]) != 0 {
            try? fileManager.removeItem(at: stagingURL)
            return false
        }
        do {
            _ = try fileManager.replaceItemAt(
                targetURL,
                withItemAt: stagingURL,
                backupItemName: nil,
                options: []
            )
            return true
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            return false
        }
    }

    /// Rsync the mounted bundle *into* the target bundle so the target matches the source, including
    /// removing files that no longer exist in the new build. Covered by `ReleaseDMGInstallerTests`.
    static func runRsyncInPlace(mountedApp: String, targetBundlePath: String) -> Int32 {
        run(
            executable: rsync,
            arguments: [
                "-a", "--delete",
                bundlePathWithTrailingSlash(mountedApp),
                bundlePathWithTrailingSlash(targetBundlePath)
            ]
        )
    }

    private static func bundlePathWithTrailingSlash(_ path: String) -> String {
        path.hasSuffix("/") ? path : path + "/"
    }

    @discardableResult
    private static func run(executable: String, arguments: [String]) -> Int32 {
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

    private static func runRsyncWithAdministrator(mountedApp: String, targetBundlePath: String) -> Bool {
        let src = escapeForAppleScriptString(bundlePathWithTrailingSlash(mountedApp))
        let dst = escapeForAppleScriptString(bundlePathWithTrailingSlash(targetBundlePath))
        let source = """
        set src to "\(src)"
        set dst to "\(dst)"
        do shell script "/usr/bin/rsync -a --delete " & quoted form of src & " " & quoted form of dst with administrator privileges
        """
        if Thread.isMainThread {
            var errorDict: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&errorDict)
            return errorDict == nil
        } else {
            return DispatchQueue.main.sync {
                var errorDict: NSDictionary?
                NSAppleScript(source: source)?.executeAndReturnError(&errorDict)
                return errorDict == nil
            }
        }
    }

    private static func escapeForAppleScriptString(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
