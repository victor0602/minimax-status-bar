import AppKit
import SwiftUI

// MARK: - DetailView

@MainActor
struct DetailView: View {
    private enum PageRoute {
        case overview
        case settings
    }

    let quotaState: QuotaState
    let onRefresh: () -> Void
    var onOpenSettings: () -> Void = {}

    @State private var timelineAnchor = Date()
    @State private var isExiting = false
    @State private var currentRoute: PageRoute = .overview
    @State private var hasOpenedSettings = false
    @State private var settingsTab: Int = 0
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

    private var settingsBreadcrumb: String {
        let leaf = settingsTab == 1 ? "用量历史" : "通用"
        return "偏好与用量历史 / \(leaf)"
    }

    var body: some View {
        TimelineView(.periodic(from: timelineAnchor, by: 1.0)) { context in
            containerView(now: context.date)
                .frame(width: 420)
                .scaleEffect(isExiting ? 0.85 : 1.0)
                .opacity(isExiting ? 0.0 : 1.0)
                .overlay(
                    RoundedRectangle(cornerRadius: UISpec.panelCornerRadius)
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
            HeaderBarView(
                quotaState: quotaState,
                now: now,
                isShowingSettings: currentRoute == .settings,
                settingsBreadcrumb: currentRoute == .settings ? settingsBreadcrumb : nil,
                onRefresh: onRefresh,
                onOpenSettings: {
                    hasOpenedSettings = true
                    withAnimation(.easeInOut(duration: 0.16)) {
                        currentRoute = .settings
                    }
                },
                onBackFromSettings: {
                    if settingsTab != 0 {
                        // 先回到设置首页（通用），再允许返回主页面
                        settingsTab = 0
                    } else {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            currentRoute = .overview
                        }
                    }
                }
            )
            Rectangle().fill(.separator).frame(height: 0.5).opacity(0.5)
            ZStack {
                VStack(spacing: 0) {
                    OfflineBannerView(quotaState: quotaState, now: now)
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: UISpec.contentVerticalPadding + 2) {
                            if let reason = quotaState.setupReason {
                                SetupGuidanceView(reason: reason, onRetry: onRefresh)
                            }
                            DetailEmptyStateView(quotaState: quotaState, onRefresh: onRefresh)
                            skeletonView
                            CategoryCardListView(grouped: grouped)
                        }
                        .padding(.vertical, UISpec.contentVerticalPadding)
                    }
                }
                .opacity(currentRoute == .overview ? 1 : 0)
                .allowsHitTesting(currentRoute == .overview)

                if hasOpenedSettings {
                    SettingsView(defaultTabIndex: nil, isEmbedded: true, selectedTabOverride: $settingsTab)
                        .opacity(currentRoute == .settings ? 1 : 0)
                        .allowsHitTesting(currentRoute == .settings)
                }
            }
            .animation(.easeInOut(duration: 0.16), value: currentRoute)
            .frame(maxHeight: NSScreen.main.map { $0.frame.height * 0.6 } ?? 400)
            Rectangle().fill(.separator).frame(height: 0.5).opacity(0.5)
            if currentRoute == .overview {
                BottomBarView(
                    updateState: updateState,
                    onExit: triggerExitAnimation
                )
            }
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
