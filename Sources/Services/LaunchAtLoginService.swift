import Foundation
import ServiceManagement

class LaunchAtLoginService {
    static var isEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            }
            return UserDefaults.standard.bool(forKey: "launchAtLogin")
        }
        set {
            if #available(macOS 13.0, *) {
                if newValue {
                    try? SMAppService.mainApp.register()
                } else {
                    try? SMAppService.mainApp.unregister()
                }
            } else {
                UserDefaults.standard.set(newValue, forKey: "launchAtLogin")
            }
        }
    }
}
