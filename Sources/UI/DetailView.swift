import SwiftUI

// MARK: - DetailView

@MainActor
struct DetailView: View {
    let quotaState: QuotaState
    let onRefresh: () -> Void

    @State private var now: Date = Date()
    @State private var timer: Timer?
    @State private var isExiting = false
    @ObservedObject private var updateState = UpdateState.shared

    private func triggerExitAnimation() {
        withAnimation(.spring(duration: 0.35, bounce: 0.0)) {
            isExiting = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            NSApp.terminate(nil)
        }
    }

    private var grouped: [(ModelCategory, [ModelQuota])] {
        let grouped = Dictionary(grouping: quotaState.models) { $0.category }
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
            .onAppear {
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
                    now = Date()
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
    }

    @ViewBuilder
    private var containerView: some View {
        VStack(spacing: 0) {
            headerBar
            lastUpdatedText
            Rectangle().fill(.separator).frame(height: 0.5).opacity(0.5)
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 8) {
                    emptyStateView
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
                    Text("API 用量监控")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
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

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        if !quotaState.hasData && !quotaState.isLoading {
            Group {
                if let err = quotaState.lastError {
                    Text("错误：\(err)")
                        .foregroundColor(.red)
                        .font(.caption)
                } else {
                    Text("暂无数据，请点击刷新")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Category Card List

    @ViewBuilder
    private var categoryCardList: some View {
        ForEach(grouped, id: \.0) { category, models in
            VStack(alignment: .leading, spacing: 0) {
                Text(category.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .tracking(0.5)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ForEach(models, id: \.modelName) { model in
                    ModelRowView(model: model)
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
        HStack(spacing: 8) {
            exitButton
            if let release = updateState.latestRelease {
                updateButton(release)
            }
            Spacer()
            consoleButton
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

// Type-erased platform-specific style appliers
// These prevent the compiler from seeing unavailable APIs at the call site

@MainActor
private final class GlassEffectApplier: @unchecked Sendable {
    static let shared = GlassEffectApplier()
    private init() {}

    @ViewBuilder
    func apply(to view: some View) -> some View {
        view.background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

@MainActor
private final class ButtonStyleApplier: @unchecked Sendable {
    static let shared = ButtonStyleApplier()
    private init() {}

    @MainActor
    private func applyFallbackButton(to view: some View) -> some View {
        view.background(Color.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    func apply(to view: some View) -> some View {
        applyFallbackButton(to: view)
    }
}

@MainActor
private final class CardStyleApplier: @unchecked Sendable {
    static let shared = CardStyleApplier()
    private init() {}

    @MainActor
    private func applyFallbackCard(to view: some View) -> some View {
        view.background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    func apply(to view: some View) -> some View {
        applyFallbackCard(to: view)
    }
}

// MARK: - ModelRowView

struct ModelRowView: View {
    let model: ModelQuota

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(model.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(model.remainingPercent)%")
                    .font(.caption)
                    .foregroundColor(progressColor(for: model.remainingPercent))
            }

            Text(model.modelName)
                .font(.caption2)
                .foregroundColor(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 3)

                    Capsule()
                        .fill(progressColor(for: model.remainingPercent))
                        .frame(width: geometry.size.width * CGFloat(model.remainingPercent) / 100, height: 3)
                }
            }
            .frame(height: 3)

            HStack {
                Text("剩余 \(formatNumber(model.remainingCount)) / \(formatNumber(model.totalCount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("本周: \(formatNumber(model.weeklyRemaining)) / \(formatNumber(model.weeklyTotal))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("重置: \(model.remainsTimeFormatted)")
                .font(.caption2)
                .foregroundColor(.secondary)
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
