import AppKit
import SwiftUI

@MainActor
class StatusBarController {
    private var statusItem: NSStatusItem
    private let quotaState = QuotaState()
    private var apiService: MiniMaxAPIService!
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var retryCount: Int = 0
    private var retryTask: Task<Void, Never>?
    /// Observer token for NSWorkspace.didWakeNotification, must be removed in deinit
    private var workspaceDidWakeObserver: NSObjectProtocol?

    /// Centralized Timer registry: key = timer name, value = active Timer
    /// Names: "polling" (quota refresh), "updateCheck" (GitHub release check), "menubarHint" (title/tooltip refresh)
    private var timers: [String: Timer] = [:]

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let apiKey = APIKeyResolver.resolve()

        let validation = APIKeyResolver.validateForQuotaAPI(apiKey)
        switch validation {
        case .valid:
            quotaState.setupReason = nil
            apiService = MiniMaxAPIService(apiKey: apiKey)
        case .missing:
            quotaState.setupReason = .missingAPIKey
            quotaState.lastError = nil
            quotaState.isLoading = false
        case .nonTokenPlanKey, .invalidFormat:
            quotaState.setupReason = .invalidTokenPlanKeyFormat
            quotaState.lastError = nil
            quotaState.isLoading = false
        }

        setupStatusBarButton()
        setupPopover()
        if apiService != nil {
            startPolling()
        }
        updateStatusBarColor()

        startUpdateTimer()
        NotificationService.shared.requestPermission()

        // Register for system sleep/wake notifications to refresh immediately on wake
        workspaceDidWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Immediately refresh once when system wakes from sleep; does not affect polling timers
            self?.manualRefresh()
        }
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
        registerTimer(name: "polling", interval: interval) { [weak self] in
            self?.refresh()
        }
        refresh()
    }

    // MARK: - Timer Management

    /// Registers a repeating timer. If a timer with the same name exists, it is cancelled and replaced.
    private func registerTimer(name: String, interval: TimeInterval, callback: @escaping () -> Void) {
        cancelTimer(name: name)
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            callback()
        }
        RunLoop.main.add(timer, forMode: .common)
        timers[name] = timer
    }

    /// Cancels and removes a named timer.
    private func cancelTimer(name: String) {
        timers[name]?.invalidate()
        timers.removeValue(forKey: name)
    }

    private func startUpdateTimer() {
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await UpdateState.shared.checkForUpdate()
        }
        // Check for updates every 6 hours
        registerTimer(name: "updateCheck", interval: 6 * 3600) {
            Task {
                await UpdateState.shared.checkForUpdate()
            }
        }
    }

    deinit {
        // Cancel all registered timers to prevent memory leaks or repeated firing
        for (_, timer) in timers {
            timer.invalidate()
        }
        timers.removeAll()
        // Remove sleep/wake notification observer to avoid dangling pointer
        if let observer = workspaceDidWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
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
        let validation = APIKeyResolver.validateForQuotaAPI(key)
        switch validation {
        case .valid:
            quotaState.setupReason = nil
            apiService = MiniMaxAPIService(apiKey: key)
        case .missing:
            quotaState.setupReason = .missingAPIKey
        case .nonTokenPlanKey, .invalidFormat:
            quotaState.setupReason = .invalidTokenPlanKeyFormat
        }
    }

    private func refresh() {
        attemptBindAPIServiceIfNeeded()
        quotaState.isLoading = true

        guard let api = apiService else {
            quotaState.isLoading = false
            updateStatusBarColor()
            return
        }

        if timers["polling"] == nil {
            registerTimer(name: "polling", interval: 60) { [weak self] in
                self?.refresh()
            }
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
                    // Write to cache for offline access
                    quotaState.cachedModels = models
                    quotaState.cachedAt = Date()
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
            // Exponential backoff: 2s → 4s → 8s
            let delayNanoseconds = UInt64(pow(2.0, Double(retryCount))) * 1_000_000_000
            retryTask = Task {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
                await MainActor.run {
                    self.refresh()
                }
            }
        } else {
            retryCount = 0
            quotaState.lastError = sanitizedError(error)
            cancelTimer(name: "menubarHint")
            updateStatusBarColor()
        }
    }

    private func startMenubarHintTimerIfNeeded() {
        cancelTimer(name: "menubarHint")
        // Refresh menu bar title/tooltip every 30s so reset countdown stays accurate between API polls
        registerTimer(name: "menubarHint", interval: 30) { [weak self] in
            self?.updateStatusBarColor()
        }
    }

    private func adjustPollingInterval() {
        guard let primary = quotaState.primaryModel else { return }
        let interval: TimeInterval = primary.remainingPercent < 10 ? 10 : 60
        registerTimer(name: "polling", interval: interval) { [weak self] in
            self?.refresh()
        }
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
            cancelTimer(name: "menubarHint")
            button.title = " ○"
            button.toolTip = "尚未连接 Token Plan，点击查看引导"
            return
        }

        // Determine primary model: use live data if available, otherwise fall back to cache
        let primaryModel = quotaState.primaryModel ?? quotaState.cachedPrimaryModel

        if primaryModel == nil {
            // No data at all (neither live nor cached)
            if quotaState.lastError != nil {
                cancelTimer(name: "menubarHint")
                button.title = " ⚠︎"
                button.toolTip = "用量获取失败，点击查看详情"
            } else {
                cancelTimer(name: "menubarHint")
                button.title = ""
                button.toolTip = "MiniMax Token Plan 用量"
            }
            return
        }

        // We have data (live or cached)
        let primary = primaryModel!
        let pct = primary.remainingPercent
        // Align with website rounding: if remaining ≥ 99%, display as 100% to match website "0% used"
        let displayPct = pct >= 99 ? 100 : pct
        let dot = displayPct > 30 ? "🟢" : (displayPct > 10 ? "🟡" : "🔴")
        let tag = primary.statusBarAbbreviation

        // If showing cached data (no live data available), append ~ to indicate stale data
        let staleIndicator = quotaState.hasData ? "" : "~"
        button.title = tag.isEmpty
            ? " \(dot) \(staleIndicator)\(displayPct)%"
            : " \(dot) \(tag)\(staleIndicator)\(displayPct)%"

        let resetHint = primary.remainsTimeFormatted
        let dataStatus = quotaState.hasData ? "" : "（缓存，可能过期）"
        button.toolTip = "\(primary.displayName) · 剩余 \(displayPct)% · 重置 \(resetHint) \(dataStatus) · 下拉查看全部模态"
    }
}
