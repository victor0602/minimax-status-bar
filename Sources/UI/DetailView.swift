import AppKit
import SwiftUI

// MARK: - DetailView

@MainActor
struct DetailView: View {
    let quotaState: QuotaState
    let onRefresh: () -> Void
    var onOpenSettings: () -> Void = {}

    @State private var timelineAnchor = Date()
    @State private var isExiting = false
    @State private var showAbout = false
    @StateObject private var updateState = UpdateState.shared
    @AppStorage(AppStorageKeys.prefersAutomaticUpdateInstall) private var prefersAutomaticUpdateInstall = false

    private func triggerExitAnimation() {
        withAnimation(PopoverChrome.exitSpring) {
            isExiting = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + PopoverChrome.exitTerminateDelay) {
            NSApp.terminate(nil)
        }
    }

    private var displayModels: [ModelQuota] {
        if quotaState.hasData {
            return quotaState.models
        }
        return quotaState.cachedModels
    }

    private var grouped: [(ModelCategory, [ModelQuota])] {
        let grouped = Dictionary(grouping: displayModels) { $0.category }
        return ModelCategory.allCases
            .compactMap { category in
                guard let models = grouped[category], !models.isEmpty else { return nil }
                return (category, models.sorted { $0.modelName < $1.modelName })
            }
            .sorted { $0.0.priority < $1.0.priority }
    }

    var body: some View {
        TimelineView(.periodic(from: timelineAnchor, by: 1.0)) { context in
            containerView(now: context.date)
                .frame(width: 320)
                .scaleEffect(isExiting ? 0.85 : 1.0)
                .opacity(isExiting ? 0.0 : 1.0)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
                .overlay(DownloadingUpdateOverlayView(updateState: updateState))
        }
        .onChange(of: prefersAutomaticUpdateInstall) { newValue in
            if newValue, let r = updateState.latestRelease, !updateState.isDownloading {
                updateState.downloadAndInstall(r)
            }
        }
    }

    @ViewBuilder
    private func containerView(now: Date) -> some View {
        VStack(spacing: 0) {
            HeaderBarView(quotaState: quotaState, showAbout: $showAbout, onRefresh: onRefresh, onOpenSettings: onOpenSettings)
            if let updated = quotaState.lastUpdatedAt {
                LastUpdatedLineView(lastUpdatedAt: updated, now: now)
            }
            OfflineBannerView(quotaState: quotaState, now: now)
            Rectangle().fill(.separator).frame(height: 0.5).opacity(0.5)
            Group {
                if showAbout {
                    AboutPanelView(prefersAutomaticUpdateInstall: $prefersAutomaticUpdateInstall)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Rectangle().fill(.separator).frame(height: 0.5).opacity(0.5)
                }
            }
            .animation(PopoverChrome.aboutSpring, value: showAbout)
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if let reason = quotaState.setupReason {
                        SetupGuidanceView(reason: reason, onRetry: onRefresh)
                    }
                    DetailEmptyStateView(quotaState: quotaState, onRefresh: onRefresh)
                    skeletonView
                    CategoryCardListView(grouped: grouped)
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: NSScreen.main.map { $0.frame.height * 0.6 } ?? 400)
            Rectangle().fill(.separator).frame(height: 0.5).opacity(0.5)
            BottomBarView(updateState: updateState, onExit: triggerExitAnimation)
        }
        .ifPlatformGlass()
    }

    @ViewBuilder
    private var skeletonView: some View {
        if quotaState.setupReason == nil, quotaState.isLoading, !quotaState.hasData {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonRowView()
            }
        }
    }
}
