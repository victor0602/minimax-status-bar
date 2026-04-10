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

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let apiKey = resolveAPIKey()

        if apiKey.isEmpty {
            quotaState.lastError = """
            未找到 MiniMax API Key

            自动查找路径：
            1. 环境变量 MINIMAX_API_KEY
            2. ~/.openclaw/.env
            3. ~/.openclaw/openclaw.json

            OpenClaw 用户重启 app 即可自动读取
            其他用户请在终端执行：
            export MINIMAX_API_KEY=your_key
            """
            quotaState.isLoading = false
        } else {
            apiService = MiniMaxAPIService(apiKey: apiKey)
        }

        setupStatusBarButton()
        setupPopover()
        if !apiKey.isEmpty {
            startPolling()
        }

        startUpdateTimer()
    }

    // MARK: - API Key Resolution

    private func resolveAPIKey() -> String {
        // 1. Environment variable
        if let key = ProcessInfo.processInfo.environment["MINIMAX_API_KEY"], !key.isEmpty {
            return key
        }

        // 2. ~/.openclaw/.env file
        let envPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw/.env")
        if let content = try? String(contentsOf: envPath, encoding: .utf8) {
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("MINIMAX_API_KEY=") {
                    var value = String(trimmed.dropFirst("MINIMAX_API_KEY=".count))
                    value = value.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                    if !value.isEmpty {
                        return value
                    }
                }
            }
        }

        // 3. ~/.openclaw/openclaw.json
        let jsonPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw/openclaw.json")
        guard let data = try? Data(contentsOf: jsonPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ""
        }

        // Path: models.providers.minimax.apiKey
        if let models = json["models"] as? [String: Any],
           let providers = models["providers"] as? [String: Any],
           let minimax = providers["minimax"] as? [String: Any],
           let apiKey = minimax["apiKey"] as? String, !apiKey.isEmpty {
            return apiKey
        }

        // Path: env.MINIMAX_API_KEY
        if let env = json["env"] as? [String: Any],
           let apiKey = env["MINIMAX_API_KEY"] as? String, !apiKey.isEmpty {
            return apiKey
        }

        return ""
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
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 450)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.setValue(true, forKeyPath: "shouldHideAnchor")

        let contentView = MenuContentView(quotaState: quotaState, onRefresh: { [weak self] in
            self?.refresh()
        })
        let hostingController = NSHostingController(rootView: contentView)

        hostingController.view.layer?.backgroundColor = CGColor(gray: 0, alpha: 0)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.contentsScale = 2.0

        popover?.contentViewController = hostingController
    }

    @objc private func togglePopover() {
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
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    private func startUpdateTimer() {
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await UpdateState.shared.checkForUpdate()
        }

        updateTimer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task {
                await UpdateState.shared.checkForUpdate()
            }
        }
    }

    private func refresh() {
        quotaState.isLoading = true

        guard let api = apiService else {
            quotaState.isLoading = false
            return
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
                    self.updateStatusBarColor()
                }
            } catch {
                await MainActor.run {
                    quotaState.lastError = self.sanitizedError(error)
                    self.updateStatusBarColor()
                }
            }
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

        if quotaState.lastError != nil {
            button.title = " 🔴"
            return
        }

        guard let primary = quotaState.primaryModel else {
            button.title = ""
            return
        }

        let remainingPercent = primary.remainingPercent
        if remainingPercent > 30 {
            button.title = " 🟢"
        } else if remainingPercent > 10 {
            button.title = " 🟡"
        } else {
            button.title = " 🔴"
        }
    }
}
