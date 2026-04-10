import SwiftUI

struct DetailView: View {
    let quotaState: QuotaState
    let onRefresh: () -> Void

    @State private var now: Date = Date()
    @State private var timer: Timer?

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
        ZStack {
            // 内容层
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
                            Button(action: {
                                print("DEBUG: Refresh button clicked")
                                onRefresh()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(7)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.interactive())
                            .keyboardShortcut("r", modifiers: .command)
                            .help("刷新数据")
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

                // 标题栏分隔线
                Rectangle()
                    .fill(.separator)
                    .frame(height: 0.5)
                    .opacity(0.5)

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
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: NSScreen.main.map { $0.frame.height * 0.6 } ?? 400)

                // 底部栏分隔线
                Rectangle()
                    .fill(.separator)
                    .frame(height: 0.5)
                    .opacity(0.5)

                // ── 底部操作栏 ──
                GlassEffectContainer {
                    HStack(spacing: 8) {
                        Button(action: { NSApplication.shared.terminate(nil) }) {
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
                        .glassEffect(.regular.interactive())
                        .keyboardShortcut("q", modifiers: .command)

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
                        .glassEffect(.regular.interactive())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 320)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                now = Date()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
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
