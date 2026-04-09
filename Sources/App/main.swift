import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// 检查是否已有实例在运行
if let bundleId = Bundle.main.bundleIdentifier {
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
    if let existingApp = runningApps.first, existingApp.processIdentifier != ProcessInfo.processInfo.processIdentifier {
        existingApp.activate(options: [.activateIgnoringOtherApps])
        exit(0)
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
