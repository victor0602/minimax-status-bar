import AppKit
import SwiftUI

class StatusBarController {
    private var statusItem: NSStatusItem
    private let quotaState = QuotaState()
    private var apiService: MiniMaxAPIService!
    private var persistenceService: DataPersistenceService!
    private var timer: Timer?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        persistenceService = DataPersistenceService()

        let apiKey = ProcessInfo.processInfo.environment["MINIMAX_API_KEY"] ?? ""
        apiService = MiniMaxAPIService(apiKey: apiKey)

        setupStatusBarButton()
        rebuildMenu()
        startPolling()
    }

    private func setupStatusBarButton() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "MiniMax Status")
            button.image?.isTemplate = true
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let contentView = MenuContentView(quotaState: quotaState, onRefresh: { [weak self] in
            self?.refresh()
        })

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 200)

        let menuItem = NSMenuItem()
        menuItem.view = hostingView
        menu.addItem(menuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
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
                    self.rebuildMenu()
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

        let usedPercent = primary.usedPercent
        if usedPercent < 70 {
            button.contentTintColor = .systemGreen
        } else if usedPercent < 90 {
            button.contentTintColor = .systemYellow
        } else {
            button.contentTintColor = .systemRed
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
