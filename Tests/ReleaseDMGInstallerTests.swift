import Foundation
import XCTest
@testable import MiniMax_Status_Bar

/// Exercises the update strategies used by `ReleaseDMGInstaller` (staging + `replaceItemAt`, and
/// `rsync --delete` fallback). These are not E2E DMG tests but verify **on-disk invariants** that block
/// broken auto-update: removed files in a new build are gone, prior bad nested bundles are not left
/// behind, and a minimal `Contents/Info.plist` + main executable are present (what relaunch needs).
final class ReleaseDMGInstallerTests: XCTestCase {
    private var workDir: URL!
    private let fileManager = FileManager.default

    override func setUp() {
        super.setUp()
        workDir = fileManager.temporaryDirectory.appendingPathComponent("RDMGTests-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: workDir, withIntermediateDirectories: true)
        } catch {
            XCTFail("setUp: \(error)")
        }
    }

    override func tearDown() {
        if let w = workDir {
            try? fileManager.removeItem(at: w)
        }
        workDir = nil
        super.tearDown()
    }

    // MARK: - Staging + replace (primary path)

    /// After a full replace, the target must look like the new source: no legacy-only files, no
    /// spurious nested `.app` that existed only in the old install.
    func testInstallByStagingDittoAndReplace_ProducesCleanNewBundleTree() throws {
        let source = workDir.appendingPathComponent("NewApp.app", isDirectory: true)
        let target = workDir.appendingPathComponent("OldApp.app", isDirectory: true)
        try writeFakeApp(
            at: source,
            resourceFiles: [
                "only_in_v2.txt": "v2"
            ],
            nestedAppFolderName: nil
        )
        try writeFakeApp(
            at: target,
            resourceFiles: [
                "legacy.txt": "old",
                "stale.nib": "nib"
            ],
            nestedAppFolderName: "Zombie Child.app"
        )

        let ok = ReleaseDMGInstaller.installByStagingDittoAndReplace(
            mountedApp: source.path,
            targetBundlePath: target.path,
            fileManager: fileManager
        )
        XCTAssertTrue(ok, "replaceItemAt should succeed for temp apps on the same volume")

        let res = target.appendingPathComponent("Contents/Resources")
        XCTAssertTrue(fileManager.fileExists(atPath: res.appendingPathComponent("only_in_v2.txt").path))
        XCTAssertEqual(
            try String(contentsOf: res.appendingPathComponent("only_in_v2.txt"), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
            "v2"
        )
        XCTAssertFalse(fileManager.fileExists(atPath: res.appendingPathComponent("legacy.txt").path))
        XCTAssertFalse(fileManager.fileExists(atPath: res.appendingPathComponent("stale.nib").path))
        let nestedZombie = res.appendingPathComponent("Zombie Child.app")
        XCTAssertFalse(fileManager.fileExists(atPath: nestedZombie.path), "stale nested bundle from old install should be removed")

        try assertBundleHasRlaunchableMinimum(appAt: target)
    }

    // MARK: - Rsync in-place (fallback)

    /// `rsync -a --delete` must make the target tree an exact mirror of the source, deleting orphans.
    func testRunRsyncInPlace_SyncsAndDeletesOrphans() throws {
        let source = workDir.appendingPathComponent("Src.app", isDirectory: true)
        let target = workDir.appendingPathComponent("Dest.app", isDirectory: true)
        // Use different byte lengths for the same file name so `rsync` (mtime+size quick check) cannot
        // skip a transfer of updated content; both 1-byte payloads can look "unchanged" in one test run.
        try writeFakeApp(
            at: source,
            resourceFiles: ["v2.txt": "payload_from_new_dmg_aaaa"],
            nestedAppFolderName: nil
        )
        try writeFakeApp(
            at: target,
            resourceFiles: [
                "v2.txt": "payload_stale_zz",
                "only_old.txt": "x"
            ],
            nestedAppFolderName: "Orphaned Nested.app"
        )

        let status = ReleaseDMGInstaller.runRsyncInPlace(
            mountedApp: source.path,
            targetBundlePath: target.path
        )
        XCTAssertEqual(status, 0)

        let res = target.appendingPathComponent("Contents/Resources")
        XCTAssertTrue(fileManager.fileExists(atPath: res.appendingPathComponent("v2.txt").path))
        XCTAssertEqual(
            try String(contentsOf: res.appendingPathComponent("v2.txt"), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
            "payload_from_new_dmg_aaaa"
        )
        XCTAssertFalse(fileManager.fileExists(atPath: res.appendingPathComponent("only_old.txt").path))
        XCTAssertFalse(fileManager.fileExists(atPath: res.appendingPathComponent("Orphaned Nested.app").path))
        try assertBundleHasRlaunchableMinimum(appAt: target)
    }

    // MARK: - Regression: merge-style update leaves junk (documented, not app code)

    /// The classic macOS `cp -R` bug when the **destination** is an existing directory: a second
    /// `.app` is placed **inside** the target. Production code avoids this via staging + `replaceItemAt` or
    /// `rsync --delete`; this only documents the bad pattern the installer must not reproduce.
    func testCpRIntoExistingBundle_NestsAppInside() throws {
        let innerName = "InnerFromDMG.app"
        let source = workDir.appendingPathComponent(innerName, isDirectory: true)
        let target = workDir.appendingPathComponent("Host.app", isDirectory: true)
        try writeFakeApp(
            at: source,
            resourceFiles: ["inner.txt": "i"],
            nestedAppFolderName: nil
        )
        try writeFakeApp(
            at: target,
            resourceFiles: ["old.txt": "o"],
            nestedAppFolderName: nil
        )

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/cp")
        p.arguments = ["-R", source.path, target.path]
        try p.run()
        p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0)

        let innerPath = target.appendingPathComponent(innerName)
        XCTAssertTrue(
            fileManager.fileExists(atPath: innerPath.path),
            "cp -R of an .app into an existing .app nests the new bundle; replace/rsync path avoids that"
        )
    }

    // MARK: - Helpers

    private func assertBundleHasRlaunchableMinimum(appAt appURL: URL) throws {
        let plist = appURL.appendingPathComponent("Contents/Info.plist")
        let exe = appURL.appendingPathComponent("Contents/MacOS/FakeExec")
        XCTAssertTrue(fileManager.fileExists(atPath: plist.path), "relaunch needs Info.plist")
        XCTAssertTrue(fileManager.fileExists(atPath: exe.path), "relaunch needs CFBundleExecutable")
        let attrs = try fileManager.attributesOfItem(atPath: exe.path)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
        XCTAssertNotEqual(perms & 0o111, 0, "main executable should be marked executable")
    }

    private func writeFakeApp(
        at appURL: URL,
        resourceFiles: [String: String],
        nestedAppFolderName: String?
    ) throws {
        let contents = appURL.appendingPathComponent("Contents", isDirectory: true)
        let resources = contents.appendingPathComponent("Resources", isDirectory: true)
        let macos = contents.appendingPathComponent("MacOS", isDirectory: true)
        try fileManager.createDirectory(at: resources, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: macos, withIntermediateDirectories: true)
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>CFBundleIdentifier</key><string>com.test.releasedmginstaller</string>
        <key>CFBundleExecutable</key><string>FakeExec</string>
        <key>CFBundlePackageType</key><string>APPL</string>
        </dict></plist>
        """
        try plist.write(to: contents.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        let fakeExec = macos.appendingPathComponent("FakeExec")
        try Data("#!/bin/sh\necho ok\n".utf8).write(to: fakeExec)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeExec.path)
        for (name, value) in resourceFiles {
            try value.write(to: resources.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        if let nested = nestedAppFolderName {
            let nestedURL = resources.appendingPathComponent(nested, isDirectory: true)
            try fileManager.createDirectory(at: nestedURL, withIntermediateDirectories: true)
            try "n".write(to: nestedURL.appendingPathComponent("holder.txt"), atomically: true, encoding: .utf8)
        }
    }
}
