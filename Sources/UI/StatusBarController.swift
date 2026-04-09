import AppKit
import SwiftUI

class StatusBarController {
    private var statusItem: NSStatusItem
    private var appState: AppState
    private var apiService: MiniMaxAPIService
    private var persistenceService: DataPersistenceService
    private var timer: Timer?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        appState = AppState()
        persistenceService = DataPersistenceService()

        let apiKey = ProcessInfo.processInfo.environment["MINIMAX_API_KEY"] ?? ""
        apiService = MiniMaxAPIService(apiKey: apiKey)

        setupStatusBarButton()
        setupMenu()
        startPolling()
    }

    private func setupStatusBarButton() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "MiniMax Status")
            button.image?.isTemplate = true
        }
    }

    private func setupMenu() {
        let menu = NSMenu()

        let contentView = MenuContentView(appState: appState, onRefresh: { [weak self] in
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
        appState.isLoading = true

        Task {
            do {
                let usage = try await apiService.fetchTokenUsage()
                await MainActor.run {
                    appState.tokenUsage = usage
                    appState.lastError = nil
                    appState.isLoading = false
                }
                persistenceService.saveUsageRecord(usage: usage, stats: appState.apiStats)
            } catch {
                await MainActor.run {
                    appState.lastError = error.localizedDescription
                    appState.isLoading = false
                }
            }
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
