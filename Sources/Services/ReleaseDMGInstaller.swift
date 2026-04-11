import AppKit
import Foundation

enum ReleaseInstallError: Error {
    case mountFailed
    case copyFailed
}

/// Mounts a DMG, replaces the running app bundle at `targetBundlePath`, then detaches and removes the DMG.
enum ReleaseDMGInstaller {
    private static let hdiutil = "/usr/bin/hdiutil"
    private static let cp = "/bin/cp"

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

        if run(executable: cp, arguments: ["-Rf", mountedApp, targetBundlePath]) != 0 {
            guard copyWithAdministrator(from: mountedApp, to: targetBundlePath) else {
                throw ReleaseInstallError.copyFailed
            }
        }
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

    private static func copyWithAdministrator(from source: String, to destination: String) -> Bool {
        let script = """
        do shell script "cp -Rf '\(source)' '\(destination)'" with administrator privileges
        """
        var errorDict: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&errorDict)
        return errorDict == nil
    }
}
