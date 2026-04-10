import SwiftUI

// MARK: - DetailView

struct DetailView: View {
    let quotaState: QuotaState
    let onRefresh: () -> Void

    @State private var now: Date = Date()
    @State private var timer: Timer?
    @State private var isExiting = false

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
            .onAppear {
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    now = Date()
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
    }

    @ViewBuilder
    private var containerView: some View {
        if #available(macOS 26.0, *) {
            ZStack {
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
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        } else {
            ZStack {
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
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Header Bar

    @ViewBuilder
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

    // MARK: - Refresh Button

    @ViewBuilder
    private var refreshButton: some View {
        Button(action: { onRefresh() }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .medium))
                .padding(7)
        }
        .buttonStyle(.plain)
        .refreshButtonStyle()
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
            .categoryCardStyle()
            .padding(.horizontal, 8)
        }
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        HStack(spacing: 8) {
            exitButton
            consoleButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @ViewBuilder
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
        .actionButtonStyle()
        .keyboardShortcut("q", modifiers: .command)
    }

    @ViewBuilder
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
        .actionButtonStyle()
    }
}

// MARK: - Platform-specific view modifiers

extension View {
    @ViewBuilder
    fileprivate func refreshButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.interactive())
        } else {
            self.background(Color.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    fileprivate func actionButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.interactive())
        } else {
            self.background(Color.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    fileprivate func categoryCardStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        } else {
            self.background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        }
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
