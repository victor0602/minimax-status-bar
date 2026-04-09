import SwiftUI

struct DetailView: View {
    let quotaState: QuotaState
    let onRefresh: () -> Void

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
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── 标题栏 ──
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
                        Button(action: onRefresh) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut("r", modifiers: .command)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // ── 最后更新时间 ──
            if let updated = quotaState.lastUpdatedAt {
                Text("最后更新：\(relativeTime(updated))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
            }

            Divider()

            // ── 可滚动区域（模型列表）──
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 8) {

                    // 无数据状态
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

                    // 分组模型列表
                    ForEach(grouped, id: \.0) { category, models in
                        VStack(alignment: .leading, spacing: 0) {
                            // 分类标题
                            Text(category.rawValue)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                .tracking(0.5)
                                .padding(.horizontal, 14)
                                .padding(.top, 8)
                                .padding(.bottom, 4)

                            // 模型卡片
                            ForEach(models, id: \.modelName) { model in
                                ModelRowView(model: model)
                                if model.modelName != models.last?.modelName {
                                    Divider().padding(.leading, 14)
                                }
                            }
                        }
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: NSScreen.main.map { $0.frame.height * 0.6 } ?? 400)

            Divider()

            // ── 底部操作栏 ──
            HStack {
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Label("退出", systemImage: "power")
                        .font(.system(size: 11))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q", modifiers: .command)

                Spacer()

                Button(action: {
                    if let url = URL(string: "https://platform.minimax.io/user-center/payment/token-plan") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label("控制台", systemImage: "arrow.up.right.square")
                        .font(.system(size: 11))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
    }
}

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
