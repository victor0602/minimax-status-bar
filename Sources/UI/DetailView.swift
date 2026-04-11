import SwiftUI

// MARK: - DetailView

@MainActor
struct DetailView: View {
    let quotaState: QuotaState
    let onRefresh: () -> Void

    @State private var now: Date = Date()
    @State private var isExiting = false
    @State private var showAbout = false
    @StateObject private var updateState = UpdateState.shared

    private func triggerExitAnimation() {
        withAnimation(.spring(duration: 0.35, bounce: 0.0)) {
            isExiting = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            NSApp.terminate(nil)
        }
    }

    /// Returns the models to display: live data if available, otherwise cached data
    private var displayModels: [ModelQuota] {
        // If we have live data, use it; otherwise fall back to cache
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

    private func relativeTime(_ date: Date) -> String {
        let diff = Int(now.timeIntervalSince(date))
        if diff < 10 { return "刚刚" }
        if diff < 60 { return "\(diff)s 前" }
        if diff < 3600 { return "\(diff / 60)m 前" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }

    var body: some View {
        containerView
            .frame(width: 320)
            .scaleEffect(isExiting ? 0.85 : 1.0)
            .opacity(isExiting ? 0.0 : 1.0)
            .blur(radius: isExiting ? 8 : 0)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .overlay(downloadingOverlay)
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
                now = date
            }
    }

    @ViewBuilder
    private var containerView: some View {
        VStack(spacing: 0) {
            headerBar
            lastUpdatedText
            offlineCacheBanner
            Rectangle().fill(.separator).frame(height: 0.5).opacity(0.5)
            if showAbout {
                aboutPanel
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                Rectangle().fill(.separator).frame(height: 0.5).opacity(0.5)
            }
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if let reason = quotaState.setupReason {
                        SetupGuidanceView(reason: reason, onRetry: onRefresh)
                    }
                    emptyStateView
                    skeletonView
                    categoryCardList
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: NSScreen.main.map { $0.frame.height * 0.6 } ?? 400)
            Rectangle().fill(.separator).frame(height: 0.5).opacity(0.5)
            bottomBar
        }
        .ifPlatformGlass()
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MiniMax")
                        .font(.system(size: 13, weight: .semibold))
                    Button(action: { withAnimation(.spring(duration: 0.25)) { showAbout.toggle() } }) {
                        HStack(spacing: 3) {
                            Text(quotaState.setupReason != nil ? "用量感知 · 待连接" : "Token Plan 用量")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Image(systemName: showAbout ? "chevron.up" : "info.circle")
                                .font(.system(size: 8))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        }
                    }
                    .buttonStyle(.plain)
                    .help("关于此应用")
                }
                Spacer()
                HStack(spacing: 6) {
                    if quotaState.isLoading {
                        ProgressView().scaleEffect(0.6)
                    }
                    refreshButton
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var refreshButton: some View {
        Button(action: { onRefresh() }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .medium))
                .padding(7)
        }
        .buttonStyle(.plain)
        .ifPlatformButton()
        .keyboardShortcut("r", modifiers: .command)
        .help("刷新数据")
    }

    // MARK: - Last Updated

    @ViewBuilder
    private var lastUpdatedText: some View {
        if let updated = quotaState.lastUpdatedAt {
            Text("最后更新：\(relativeTime(updated))")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
        }
    }

    // MARK: - Offline Cache Banner

    /// Shows cached data age when API fails but cache exists
    @ViewBuilder
    private var offlineCacheBanner: some View {
        // Show banner when: has error, no live data, but has cached data
        if quotaState.lastError != nil, !quotaState.hasData, quotaState.hasCachedData, let cachedAt = quotaState.cachedAt {
            let ageMinutes = Int(now.timeIntervalSince(cachedAt) / 60)
            let ageText = ageMinutes < 1 ? "刚刚" : "\(ageMinutes) 分钟前"
            HStack(spacing: 4) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 9))
                Text("数据来自 \(ageText)，当前无法连接")
                    .font(.system(size: 10))
            }
            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        // Show empty state only when: no setup reason, no live data, no cache, and not loading
        if quotaState.setupReason == nil, !quotaState.hasData, !quotaState.hasCachedData, !quotaState.isLoading {
            VStack(spacing: 12) {
                Image(systemName: quotaState.lastError != nil
                      ? "exclamationmark.triangle"
                      : "chart.bar.xaxis")
                    .font(.system(size: 32))
                    .foregroundColor(quotaState.lastError != nil ? .orange : .secondary)

                Text(quotaState.lastError != nil ? "暂时无法获取用量" : "暂无数据")
                    .font(.system(size: 13, weight: .medium))

                Text(quotaState.lastError ?? "点击刷新拉取最新配额；与控制台数字应以「剩余」一致。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: { onRefresh() }) {
                    Text("刷新")
                        .font(.system(size: 11))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .ifPlatformButton()
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Skeleton Loading

    @ViewBuilder
    private var skeletonView: some View {
        if quotaState.setupReason == nil, quotaState.isLoading, !quotaState.hasData {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonRowView()
            }
        }
    }

    // MARK: - Category Card List

    @ViewBuilder
    private var categoryCardList: some View {
        ForEach(grouped, id: \.0) { category, models in
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: category.icon)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    Text(category.rawValue.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        .tracking(0.5)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // Explanatory text for Unknown category
                if category == .unknown {
                    Text("以下模型暂未识别分类，数据仍然有效")
                        .font(.system(size: 9))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        .padding(.horizontal, 14)
                        .padding(.bottom, 4)
                }

                ForEach(models, id: \.modelName) { model in
                    ModelRowView(model: model, showUnrecognizedTag: category == .unknown)
                    if model.modelName != models.last?.modelName {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .ifPlatformCard()
            .padding(.horizontal, 8)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                exitButton
                Spacer()
                if let release = updateState.latestRelease {
                    updateButton(release)
                }
                launchAtLoginButton
                consoleButton
            }
            versionBar
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func updateButton(_ release: ReleaseInfo) -> some View {
        Button(action: {
            updateState.downloadAndInstall(release)
        }) {
            HStack(spacing: 3) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 10))
                Text("更新 v\(release.version)")
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .ifPlatformButton()
        .foregroundColor(.blue)
    }

    private var launchAtLoginButton: some View {
        Button(action: {
            LaunchAtLoginService.isEnabled.toggle()
        }) {
            Image(systemName: LaunchAtLoginService.isEnabled ? "power.circle.fill" : "power.circle")
                .font(.system(size: 14))
                .foregroundColor(LaunchAtLoginService.isEnabled ? .green : .secondary)
        }
        .buttonStyle(.plain)
        .ifPlatformButton()
        .help(LaunchAtLoginService.isEnabled ? "已开启开机启动" : "开启开机启动")
    }

    @ViewBuilder
    private var downloadingOverlay: some View {
        if updateState.isDownloading {
            ZStack {
                Color.black.opacity(0.5)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(spacing: 12) {
                    if updateState.installPhase == "下载中" {
                        Text("正在下载更新...")
                            .font(.system(size: 13, weight: .medium))
                        ProgressView(value: updateState.downloadProgress)
                            .frame(width: 200)
                        Text("\(Int(updateState.downloadProgress * 100))%")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Button("取消") {
                            updateState.cancelDownload()
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.plain)
                    } else if updateState.installPhase == "安装中" {
                        Text("正在安装更新...")
                            .font(.system(size: 13, weight: .medium))
                        ProgressView()
                            .frame(width: 200)
                        Text("请稍候")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else if updateState.installPhase == "重启中" {
                        Text("更新完成，正在重启...")
                            .font(.system(size: 13, weight: .medium))
                        ProgressView()
                            .frame(width: 200)
                    }
                }
                .padding(24)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .transition(.opacity)
        }
    }

    private var exitButton: some View {
        Button(action: { triggerExitAnimation() }) {
            HStack(spacing: 4) {
                Image(systemName: "power")
                    .font(.system(size: 10))
                Text("退出")
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .ifPlatformButton()
        .keyboardShortcut("q", modifiers: .command)
    }

    private var consoleButton: some View {
        Button(action: {
            if let url = URL(string: "https://platform.minimaxi.com/user-center/payment/token-plan") {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack(spacing: 3) {
                Text("控制台")
                    .font(.system(size: 11))
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 9))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .ifPlatformButton()
    }

    private var versionBar: some View {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return HStack(spacing: 6) {
            // 版本号
            Text("v\(currentVersion)")
                .font(.system(size: 9))
                .foregroundColor(Color(nsColor: .quaternaryLabelColor))

            // 可用更新提示
            if let release = updateState.latestRelease {
                Text("→ v\(release.version) 可用")
                    .font(.system(size: 9))
                    .foregroundColor(.blue.opacity(0.7))
            }

            Spacer()

            // GitHub 链接
            Button(action: {
                if let url = URL(string: "https://github.com/victor0602/minimax-status-bar") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "curlybraces")
                        .font(.system(size: 8))
                    Text("GitHub")
                        .font(.system(size: 9))
                }
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
            .buttonStyle(.plain)
            .help("在 GitHub 上查看源码")
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    // MARK: - About Panel

    /// 关于面板：长按版本号触发，显示 App 简介与相关链接
    private var aboutPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let icon = NSImage(named: "StatusBarIcon") {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .opacity(0.85)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("MiniMax Status Bar")
                        .font(.system(size: 12, weight: .semibold))
                    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                    Text("v\(currentVersion) · macOS 13.0+")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Text("为重度使用 MiniMax Token Plan 的开发者而生。菜单栏一眼感知配额，零配置，零打扰。")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                aboutLink(
                    icon: "doc.text",
                    title: "MiniMax Token Plan 控制台",
                    url: "https://platform.minimaxi.com/user-center/payment/token-plan"
                )
                aboutLink(
                    icon: "curlybraces",
                    title: "GitHub 源码",
                    url: "https://github.com/victor0602/minimax-status-bar"
                )
                aboutLink(
                    icon: "arrow.down.circle",
                    title: "检查更新",
                    url: "https://github.com/victor0602/minimax-status-bar/releases/latest"
                )
            }

            Text("MIT License · © \(Calendar.current.component(.year, from: Date())) Victor")
                .font(.system(size: 9))
                .foregroundColor(Color(nsColor: .quaternaryLabelColor))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
        }
        .padding(14)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 2)
    }

    private func aboutLink(icon: String, title: String, url: String) -> some View {
        Button(action: {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .frame(width: 14)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Platform-specific modifiers via type-erased wrappers

extension View {
    @ViewBuilder
    fileprivate func ifPlatformGlass() -> some View {
        GlassEffectApplier.shared.apply(to: self)
    }

    @ViewBuilder
    fileprivate func ifPlatformButton() -> some View {
        ButtonStyleApplier.shared.apply(to: self)
    }

    @ViewBuilder
    fileprivate func ifPlatformCard() -> some View {
        CardStyleApplier.shared.apply(to: self)
    }
}

// MARK: - SkeletonRowView

struct SkeletonRowView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 120, height: 12)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 40, height: 12)
            }
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.primary.opacity(0.08))
                .frame(height: 5)
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.07))
                    .frame(width: 80, height: 10)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.07))
                    .frame(width: 60, height: 10)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .redacted(reason: .placeholder)
    }
}

// MARK: - ModelRowView

struct ModelRowView: View {
    let model: ModelQuota
    /// Shows "未适配" tag next to model name for unrecognized models
    var showUnrecognizedTag: Bool = false
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                HStack(spacing: 4) {
                    Text(model.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if showUnrecognizedTag {
                        Text("未适配")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color(nsColor: .tertiaryLabelColor).opacity(0.2))
                            )
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("剩余 \(model.remainingPercent)%")
                        .font(.caption)
                        .foregroundColor(progressColor(for: model.remainingPercent))
                    Text("已用 \(model.intervalConsumedPercent)%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(colorScheme == .dark
                              ? Color.white.opacity(0.12)
                              : Color.black.opacity(0.08))
                        .frame(height: 5)

                    Capsule()
                        .fill(progressColor(for: model.remainingPercent))
                        .frame(width: geometry.size.width * CGFloat(model.remainingPercent) / 100, height: 5)
                }
            }
            .frame(height: 5)

            HStack {
                Text("剩余 \(formatNumber(model.remainingCount)) / \(formatNumber(model.totalCount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("重置: \(model.remainsTimeFormatted)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    Text("本周剩余 \(formatNumber(model.weeklyRemainingCount)) / 限额 \(formatNumber(model.weeklyTotalCount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("本周已用 \(formatNumber(model.weeklyConsumedCount))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func progressColor(for percent: Int) -> Color {
        if percent > 30 { return .green }
        if percent > 10 { return .yellow }
        return .red
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1_000_000_000 {
            return String(format: "%.1fB", Double(num) / 1_000_000_000)
        } else if num >= 1_000_000 {
            return String(format: "%.1fM", Double(num) / 1_000_000)
        } else if num >= 1_000 {
            return String(format: "%.1fK", Double(num) / 1_000)
        }
        return "\(num)"
    }
}
