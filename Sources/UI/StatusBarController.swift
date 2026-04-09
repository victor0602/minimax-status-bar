import AppKit
import SwiftUI

class StatusBarController {
    private var statusItem: NSStatusItem
    private let quotaState = QuotaState()
    private var apiService: MiniMaxAPIService!
    private var persistenceService: DataPersistenceService!
    private var timer: Timer?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        persistenceService = DataPersistenceService()

        let apiKey = ProcessInfo.processInfo.environment["MINIMAX_API_KEY"] ?? ""
        apiService = MiniMaxAPIService(apiKey: apiKey)

        setupStatusBarButton()
        setupPopover()
        startPolling()
    }

    private func setupStatusBarButton() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "MiniMax Status")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        popover?.animates = true

        let contentView = MenuContentView(quotaState: quotaState, onRefresh: { [weak self] in
            self?.refresh()
        })
        popover?.contentViewController = NSHostingController(rootView: contentView)

        // Optimize for 120Hz promotion displays
        if let view = popover?.contentViewController?.view {
            view.wantsLayer = true
            view.layer?.contentsScale = 2.0
        }
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
        stopEventMonitor()
    }

    private func stopEventMonitor() {
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

    private func refresh() {
        quotaState.isLoading = true

        Task {
            do {
                let models = try await self.apiService.fetchQuota()
                await MainActor.run {
                    self.quotaState.models = models
                    self.quotaState.lastUpdatedAt = Date()
                    self.quotaState.lastError = nil
                    self.quotaState.isLoading = false
                    self.updateStatusBarColor()
                }
                self.persistenceService.saveHistory(models)
            } catch {
                await MainActor.run {
                    self.quotaState.lastError = error.localizedDescription
                    self.quotaState.isLoading = false
                    self.updateStatusBarColor()
                }
            }
        }
    }

    private func updateStatusBarColor() {
        guard let button = statusItem.button else { return }

        if quotaState.lastError != nil {
            button.contentTintColor = .systemRed
            return
        }

        guard let primary = quotaState.primaryModel else {
            button.contentTintColor = .systemGray
            return
        }

        let remainingPercent = primary.remainingPercent
        if remainingPercent > 30 {
            button.contentTintColor = .systemGreen
        } else if remainingPercent > 10 {
            button.contentTintColor = .systemYellow
        } else {
            button.contentTintColor = .systemRed
        }
    }
}
