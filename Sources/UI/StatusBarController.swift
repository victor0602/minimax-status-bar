import AppKit
import SwiftUI

@MainActor
class StatusBarController {
    private var statusItem: NSStatusItem
    private let quotaState = QuotaState()
    private var apiService: MiniMaxAPIService!
    private var timer: Timer?
    private var updateTimer: Timer?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var retryCount: Int = 0
    private var retryTask: Task<Void, Never>?
    /// Refreshes menu bar tooltip/title so reset countdown stays believable between API polls.
    private var menubarHintTimer: Timer?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let apiKey = APIKeyResolver.resolve()

        if apiKey.isEmpty {
            quotaState.setupReason = .missingAPIKey
            quotaState.lastError = nil
            quotaState.isLoading = false
        } else if !apiKey.hasPrefix("sk-") && !apiKey.hasPrefix("sk-cp-") {
            quotaState.setupReason = .invalidTokenPlanKeyFormat
            quotaState.lastError = nil
            quotaState.isLoading = false
        } else {
            quotaState.setupReason = nil
            apiService = MiniMaxAPIService(apiKey: apiKey)
        }

        setupStatusBarButton()
        setupPopover()
        if apiService != nil {
            startPolling()
        }
        updateStatusBarColor()

        startUpdateTimer()
        NotificationService.shared.requestPermission()
    }

    private func setupStatusBarButton() {
        if let button = statusItem.button {
            if let image = NSImage(named: "StatusBarIcon") {
                image.isTemplate = true
                button.image = image
            } else {
                button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "MiniMax Status")
                button.image?.isTemplate = true
            }
            button.action = #selector(togglePopover)
            button.target = self
            button.toolTip = "MiniMax Token Plan 用量"
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 450)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.setValue(true, forKeyPath: "shouldHideAnchor")

        let contentView = MenuContentView(quotaState: quotaState, onRefresh: { [weak self] in
            self?.manualRefresh()
        })
        let hostingController = NSHostingController(rootView: contentView)

        hostingController.view.layer?.backgroundColor = CGColor(gray: 0, alpha: 0)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.contentsScale = 2.0

        popover?.contentViewController = hostingController
    }

    @objc private func togglePopover() {
        Task { @MainActor in
            self.doTogglePopover()
        }
    }

    @MainActor
    private func doTogglePopover() {
        guard let popover = popover, let button = statusItem.button else { return }

        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startEventMonitor()
        }
    }

    private func startEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover?.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func startPolling(interval: TimeInterval = 60) {
        setupTimer(interval: interval)
        refresh()
    }

    private func setupTimer(interval: TimeInterval) {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func startUpdateTimer() {
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await UpdateState.shared.checkForUpdate()
        }

        updateTimer?.invalidate()
        let newUpdateTimer = Timer(timeInterval: 6 * 3600, repeats: true) { _ in
            Task {
                await UpdateState.shared.checkForUpdate()
            }
        }
        RunLoop.main.add(newUpdateTimer, forMode: .common)
        updateTimer = newUpdateTimer
    }

    private func manualRefresh() {
        retryCount = 0
        retryTask?.cancel()
        retryTask = nil
        refresh()
    }

    /// Re-read env / OpenClaw files and create `MiniMaxAPIService` when the user fixes configuration without relaunching.
    private func attemptBindAPIServiceIfNeeded() {
        guard apiService == nil else { return }
        let key = APIKeyResolver.resolve()
        if key.isEmpty {
            quotaState.setupReason = .missingAPIKey
            return
        }
        if !key.hasPrefix("sk-") && !key.hasPrefix("sk-cp-") {
            quotaState.setupReason = .invalidTokenPlanKeyFormat
            return
        }
        quotaState.setupReason = nil
        apiService = MiniMaxAPIService(apiKey: key)
    }

    private func refresh() {
        attemptBindAPIServiceIfNeeded()
        quotaState.isLoading = true

        guard let api = apiService else {
            quotaState.isLoading = false
            updateStatusBarColor()
            return
        }

        if timer == nil {
            setupTimer(interval: 60)
        }

        Task { [api] in
            defer {
                Task { @MainActor in
                    quotaState.isLoading = false
                }
            }

            do {
                let models = try await api.fetchQuota()
                await MainActor.run {
                    quotaState.models = models
                    quotaState.lastUpdatedAt = Date()
                    quotaState.lastError = nil
                    quotaState.setupReason = nil
                    self.retryCount = 0
                    self.adjustPollingInterval()
                    self.updateStatusBarColor()
                    NotificationService.shared.checkAndNotify(primary: self.quotaState.primaryModel)
                    self.startMenubarHintTimerIfNeeded()
                }
            } catch {
                await MainActor.run {
                    self.handleRefreshError(error)
                }
            }
        }
    }

    private func handleRefreshError(_ error: Error) {
        if retryCount < 3 {
            retryCount += 1
            retryTask?.cancel()
            retryTask = Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await MainActor.run {
                    self.refresh()
                }
            }
        } else {
            retryCount = 0
            quotaState.lastError = sanitizedError(error)
            stopMenubarHintTimer()
            updateStatusBarColor()
        }
    }

    private func startMenubarHintTimerIfNeeded() {
        stopMenubarHintTimer()
        menubarHintTimer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateStatusBarColor()
        }
        if let menubarHintTimer {
            RunLoop.main.add(menubarHintTimer, forMode: .common)
        }
    }

    private func stopMenubarHintTimer() {
        menubarHintTimer?.invalidate()
        menubarHintTimer = nil
    }

    private func adjustPollingInterval() {
        guard let primary = quotaState.primaryModel else { return }
        let interval: TimeInterval = primary.remainingPercent < 10 ? 10 : 60
        setupTimer(interval: interval)
    }

    private func sanitizedError(_ error: Error) -> String {
        if let apiError = error as? MiniMaxAPIError {
            switch apiError {
            case .missingAPIKey:
                return """
                未找到 MiniMax API Key

                自动查找路径：
                1. 环境变量 MINIMAX_API_KEY
                2. ~/.openclaw/.env
                3. ~/.openclaw/openclaw.json

                OpenClaw 用户重启 app 即可自动读取
                其他用户请在终端执行：
                export MINIMAX_API_KEY=your_key
                """
            case .serverError(401):
                return """
                API Key 验证失败（401）

                请确认使用的是 Token Plan Key
                而非普通 Open Platform API Key

                Token Plan Key 以 sk-cp- 开头
                前往：platform.minimaxi.com/user-center/payment/token-plan
                获取 Token Plan Key
                """
            default:
                break
            }
        }
        let msg = error.localizedDescription
        return msg.replacingOccurrences(
            of: #"\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"#,
            with: "[IP]",
            options: .regularExpression
        )
    }

    private func updateStatusBarColor() {
        guard let button = statusItem.button else { return }

        if quotaState.setupReason != nil {
            stopMenubarHintTimer()
            button.title = " ○"
            button.toolTip = "尚未连接 Token Plan，点击查看引导"
            return
        }

        if quotaState.lastError != nil {
            stopMenubarHintTimer()
            button.title = " ⚠︎"
            button.toolTip = "用量获取失败，点击查看详情"
            return
        }

        guard let primary = quotaState.primaryModel else {
            stopMenubarHintTimer()
            button.title = ""
            button.toolTip = "MiniMax Token Plan 用量"
            return
        }

        let pct = primary.remainingPercent
        let dot = pct > 30 ? "🟢" : (pct > 10 ? "🟡" : "🔴")
        let tag = primary.statusBarAbbreviation
        button.title = tag.isEmpty ? " \(dot) \(pct)%" : " \(dot) \(tag)\(pct)%"
        let resetHint = primary.remainsTimeFormatted
        button.toolTip = "\(primary.displayName) · 剩余 \(pct)% · 重置 \(resetHint) · 下拉查看全部模态"
    }
}
