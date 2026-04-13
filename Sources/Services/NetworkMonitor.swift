import Foundation
import Network

/// 监听系统网络路径；从「不可用」恢复到「可用」时回调一次（用于立即重拉配额，与睡眠唤醒逻辑互补）。
final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.openclaw.minimax-status-bar.network")
    private var sawInitialPath = false
    private var lastSatisfied = false

    func start(onReachabilityRestored: @escaping () -> Void) {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.handleStatusChange(satisfied: path.status == .satisfied, onReachabilityRestored: onReachabilityRestored)
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }

    func handleStatusChange(satisfied: Bool, onReachabilityRestored: @escaping () -> Void) {
        if !sawInitialPath {
            sawInitialPath = true
            lastSatisfied = satisfied
            return
        }
        if satisfied, !lastSatisfied {
            DispatchQueue.main.async(execute: onReachabilityRestored)
        }
        lastSatisfied = satisfied
    }
}
