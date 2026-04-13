import AppKit
import Combine
import SwiftUI

@MainActor
/// AppKit 菜单栏控制器：负责状态栏渲染、轮询刷新、错误退避重试、睡眠/网络恢复刷新、更新检查等编排。
final class StatusBarController {
    private var statusItem: NSStatusItem
    private let quotaState: QuotaState
    private var apiService: (any APIServiceProtocol)?
    private var networkMonitor: NetworkMonitor?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var retryCount: Int = 0
    private var retryTask: Task<Void, Never>?
    private var workspaceDidWakeObserver: NSObjectProtocol?
    private var preferencesObserver: NSObjectProtocol?

    private var cancellables = Set<AnyCancellable>()
    private var timers: [String: Timer] = [:]
    /// 刷新动画状态：0 = 无动画，1 = ↻ 帧，2 = ⟳ 帧
    private var refreshAnimationFrame: Int = 0

    // MARK: - Timer Documentation
    // polling: 每 30/60/120/300 秒触发一次（用户可配置），负责自动刷新配额数据
    // updateCheck: 每 6 小时触发一次，检查 GitHub 是否有新版本发布
    // menubarHint: 固定 30 秒触发一次，用于菜单栏标题的实时倒计时更新（如剩余时间）

    init(persistence: QuotaStatePersistence = UserDefaultsQuotaPersistence()) {
        quotaState = QuotaState(persistence: persistence)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let apiKey = Self.resolvedAPIKey()
        let validation = APIKeyService.validateForQuotaAPI(apiKey)
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
        observeUpdateAvailability()

        workspaceDidWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.manualRefresh()
            }
        }

        networkMonitor = NetworkMonitor()
        networkMonitor?.start { [weak self] in
            self?.manualRefresh()
        }

        preferencesObserver = NotificationCenter.default.addObserver(
            forName: .minimaxPreferencesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildAPIService()
                self?.restartPollingFromUserDefaults()
                self?.updateStatusBarColor()
            }
        }
    }

    private static func resolvedAPIKey() -> String {
        APIKeyService.resolve()
    }

    private func menuBarDisplayMode() -> MenuBarDisplayMode {
        let raw = UserDefaults.standard.string(forKey: AppStorageKeys.menuBarDisplayMode)
        return MenuBarDisplayMode(rawValue: raw ?? MenuBarDisplayMode.concise.rawValue) ?? .concise
    }

    private func basePollingInterval() -> TimeInterval {
        let v = UserDefaults.standard.object(forKey: AppStorageKeys.refreshIntervalSeconds) as? Int ?? 60
        let allowed = [30, 60, 120, 300]
        return TimeInterval(allowed.contains(v) ? v : 60)
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

        let contentView = MenuContentView(
            quotaState: quotaState,
            onRefresh: { [weak self] in self?.manualRefresh() },
            onOpenSettings: {
                Task { @MainActor in
                    (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
                }
            }
        )
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

    private func startPolling() {
        registerTimer(name: "polling", interval: basePollingInterval()) { [weak self] in
            self?.refresh()
        }
        refresh()
    }

    private func registerTimer(name: String, interval: TimeInterval, callback: @escaping () -> Void) {
        cancelTimer(name: name)
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            callback()
        }
        RunLoop.main.add(timer, forMode: .common)
        timers[name] = timer
    }

    private func cancelTimer(name: String) {
        timers[name]?.invalidate()
        timers.removeValue(forKey: name)
    }

    private func observeUpdateAvailability() {
        UpdateState.shared.$latestRelease
            .receive(on: DispatchQueue.main)
            .removeDuplicates { $0?.version == $1?.version }
            .sink { [weak self] release in
                self?.updateStatusBarColor()
                if let release {
                    NotificationService.shared.offerUpdateAvailable(release)
                    self?.maybeStartAutomaticUpdateInstallIfNeeded(release: release)
                }
            }
            .store(in: &cancellables)
    }

    private func maybeStartAutomaticUpdateInstallIfNeeded(release: ReleaseInfo) {
        guard UserDefaults.standard.bool(forKey: AppStorageKeys.prefersAutomaticUpdateInstall) else { return }
        guard !UpdateState.shared.isDownloading else { return }
        let version = release.version
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard UserDefaults.standard.bool(forKey: AppStorageKeys.prefersAutomaticUpdateInstall) else { return }
            guard !UpdateState.shared.isDownloading else { return }
            guard UpdateState.shared.latestRelease?.version == version else { return }
            UpdateState.shared.downloadAndInstall(release)
        }
    }

    private func startUpdateTimer() {
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await UpdateState.shared.checkForUpdate()
        }
        registerTimer(name: "updateCheck", interval: 6 * 3600) {
            Task {
                await UpdateState.shared.checkForUpdate()
            }
        }
    }

    deinit {
        for (_, timer) in timers { timer.invalidate() }
        timers.removeAll()
        if let observer = workspaceDidWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = preferencesObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        networkMonitor?.stop()
        networkMonitor = nil
    }

    private func manualRefresh() {
        retryCount = 0
        retryTask?.cancel()
        retryTask = nil
        refresh()
    }

    private func rebuildAPIService() {
        let key = Self.resolvedAPIKey()
        let validation = APIKeyService.validateForQuotaAPI(key)
        switch validation {
        case .valid:
            quotaState.setupReason = nil
            apiService = MiniMaxAPIService(apiKey: key)
            if timers["polling"] == nil {
                startPolling()
            } else {
                manualRefresh()
            }
        case .missing:
            apiService = nil
            cancelTimer(name: "polling")
            quotaState.setupReason = .missingAPIKey
            quotaState.isLoading = false
        case .nonTokenPlanKey, .invalidFormat:
            apiService = nil
            cancelTimer(name: "polling")
            quotaState.setupReason = .invalidTokenPlanKeyFormat
            quotaState.isLoading = false
        }
        updateStatusBarColor()
    }

    private func restartPollingFromUserDefaults() {
        guard apiService != nil else { return }
        adjustPollingInterval()
    }

    private func attemptBindAPIServiceIfNeeded() {
        guard apiService == nil else { return }
        let key = Self.resolvedAPIKey()
        let validation = APIKeyService.validateForQuotaAPI(key)
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
        startRefreshAnimation()
        updateStatusBarColor()

        guard let api = apiService else {
            quotaState.isLoading = false
            updateStatusBarColor()
            return
        }

        if timers["polling"] == nil {
            registerTimer(name: "polling", interval: basePollingInterval()) { [weak self] in
                self?.refresh()
            }
        }

        Task { [api] in
            defer {
                Task { @MainActor in
                    quotaState.isLoading = false
                    self.stopRefreshAnimation()
                    self.updateStatusBarColor()
                }
            }

            do {
                let models = try await api.fetchQuota()
                await MainActor.run {
                    #if DEBUG
                    let issues = CacheConsistencyChecker.validationIssues(for: models, against: quotaState.cachedModels)
                    if !issues.isEmpty {
                        print("MiniMax Status Bar [DEBUG] quota validation: \(issues.joined(separator: "; "))")
                    }
                    #endif
                    quotaState.commitSuccessfulFetch(models: models)
                    let primaryName = quotaState.primaryModel?.modelName ?? ""
                    UsageHistoryRecorder.recordSnapshot(models: models, primaryModelName: primaryName)
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
            let delayNanoseconds = UInt64(pow(2.0, Double(retryCount))) * 1_000_000_000
            retryTask = Task {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
                await MainActor.run {
                    self.refresh()
                }
            }
        } else {
            retryCount = 0
            quotaState.lastError = AppError.wrap(error)
            cancelTimer(name: "menubarHint")
            updateStatusBarColor()
        }
    }

    private func startRefreshAnimation() {
        refreshAnimationFrame = 1
        registerTimer(name: "refreshAnimation", interval: 0.4) { [weak self] in
            guard let self = self else { return }
            self.refreshAnimationFrame = self.refreshAnimationFrame == 1 ? 2 : 1
            self.updateStatusBarColor()
        }
    }

    private func stopRefreshAnimation() {
        cancelTimer(name: "refreshAnimation")
        refreshAnimationFrame = 0
    }

    private var refreshAnimationSymbol: String {
        switch refreshAnimationFrame {
        case 1: return "↻"
        case 2: return "⟳"
        default: return ""
        }
    }

    private func startMenubarHintTimerIfNeeded() {
        cancelTimer(name: "menubarHint")
        registerTimer(name: "menubarHint", interval: 30) { [weak self] in
            self?.updateStatusBarColor()
        }
    }

    private func adjustPollingInterval() {
        guard apiService != nil else { return }
        let base = basePollingInterval()
        guard let primary = quotaState.primaryModel else {
            registerTimer(name: "polling", interval: base) { [weak self] in self?.refresh() }
            return
        }
        let interval = primary.remainingPercent < 10 ? min(10, base) : base
        registerTimer(name: "polling", interval: interval) { [weak self] in
            self?.refresh()
        }
    }

    private func applyPendingUpdateMenubarIndicator(to button: NSStatusBarButton) {
        guard let release = UpdateState.shared.latestRelease else { return }
        let hint = " · 可更新 v\(release.version)"
        if button.title.trimmingCharacters(in: .whitespaces).isEmpty {
            button.title = "⬆"
        } else {
            button.title = (button.title) + " ⬆"
        }
        button.toolTip = (button.toolTip ?? "") + hint
    }

    private func updateStatusBarColor() {
        guard let button = statusItem.button else { return }

        if quotaState.setupReason != nil {
            cancelTimer(name: "menubarHint")
            button.title = " ○"
            button.toolTip = "尚未连接 Token Plan，点击查看引导"
            applyPendingUpdateMenubarIndicator(to: button)
            return
        }

        let primaryModel = quotaState.primaryModel ?? quotaState.cachedPrimaryModel

        if primaryModel == nil {
            if quotaState.lastError != nil {
                cancelTimer(name: "menubarHint")
                button.title = " ⚠︎"
                button.toolTip = "用量获取失败，点击查看详情"
            } else {
                cancelTimer(name: "menubarHint")
                button.title = ""
                button.toolTip = "MiniMax Token Plan 用量"
            }
            applyPendingUpdateMenubarIndicator(to: button)
            return
        }

        let primary = primaryModel!
        // 使用 remainingPercentForDisplay 确保与"已用"互补为 100%
        let pct = primary.remainingPercentForDisplay
        let displayPct = pct >= 99 ? 100 : pct
        let dot = displayPct > 30 ? "🟢" : (displayPct > 10 ? "🟡" : "🔴")
        let tag = primary.statusBarAbbreviation
        let staleIndicator = quotaState.hasData ? "" : "~"
        let verboseSuffix = menuBarDisplayMode() == .verbose ? " \(primary.formattedRemainingCountShort)" : ""
        let loadPrefix = quotaState.isLoading ? "\(refreshAnimationSymbol) " : ""

        if tag.isEmpty {
            button.title = " \(loadPrefix)\(dot) \(staleIndicator)\(displayPct)%\(verboseSuffix)"
        } else {
            button.title = " \(loadPrefix)\(dot) \(tag)\(staleIndicator)\(displayPct)%\(verboseSuffix)"
        }

        let resetHint = primary.remainsTimeFormatted
        let dataStatus = quotaState.hasData ? "" : "（缓存，可能过期）"
        button.toolTip = "\(primary.displayName) · 剩余 \(displayPct)% · 重置 \(resetHint) \(dataStatus) · 下拉查看全部模态"
        applyPendingUpdateMenubarIndicator(to: button)
    }
}
