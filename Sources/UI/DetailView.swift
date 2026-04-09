import SwiftUI

struct DetailView: View {
    let quotaState: QuotaState
    let onRefresh: () -> Void

    private var sortedModels: [ModelQuota] {
        quotaState.models.sorted { $0.modelName < $1.modelName }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── 顶部标题栏（固定不滚动）──
            HStack {
                Text("MiniMax Status")
                    .font(.headline)
                Spacer()
                if quotaState.isLoading {
                    ProgressView().scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()

            // ── 可滚动区域（模型列表）──
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 0) {

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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }

                    // 模型列表
                    ForEach(sortedModels, id: \.modelName) { model in
                        ModelRowView(model: model)
                        if model.modelName != sortedModels.last?.modelName {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
            .frame(maxHeight: NSScreen.main.map { $0.frame.height * 0.6 } ?? 400)

            Divider()

            // ── 底部栏（固定不滚动）──
            HStack {
                Button(action: onRefresh) {
                    Label("刷新", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Spacer()

                if let updated = quotaState.lastUpdatedAt {
                    Text("最后更新：\(relativeTime(updated))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .frame(width: 300)
    }
}

struct ModelRowView: View {
    let model: ModelQuota

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(progressColor(for: model.remainingPercent))
                        .frame(width: geometry.size.width * CGFloat(model.remainingPercent) / 100, height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text("剩余 \(formatNumber(model.remainingCount)) / \(formatNumber(model.totalCount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("本周: \(formatNumber(model.weeklyRemaining)) / \(formatNumber(model.weeklyTotal))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("重置: \(model.remainsTimeFormatted)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
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
