import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// 检查是否已有实例在运行（XCTest 宿主启动时会再拉起同 bundle 进程，不能在此处 exit）
let isXCTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
if !isXCTestHost, let bundleId = Bundle.main.bundleIdentifier {
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
    if let existingApp = runningApps.first, existingApp.processIdentifier != ProcessInfo.processInfo.processIdentifier {
        existingApp.activate(options: [.activateIgnoringOtherApps])
        exit(0)
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
