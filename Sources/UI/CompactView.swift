import SwiftUI

struct CompactView: View {
    @ObservedObject var quotaState: QuotaState

    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if quotaState.isLoading {
                HStack {
                    ProgressView()
                    Text("刷新中...")
                }
            } else if let error = quotaState.lastError {
                Text("错误: \(error)").foregroundColor(.red)
            } else if let model = quotaState.primaryModel {
                HStack {
                    Text(model.displayName)
                        .font(.headline)
                    Spacer()
                    Text("\(model.remainingPercent)%")
                        .font(.headline)
                        .foregroundColor(progressColor(for: model.remainingPercent))
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor(for: model.remainingPercent))
                            .frame(width: geometry.size.width * CGFloat(model.remainingPercent) / 100, height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("剩余 \(formatNumber(model.remainingCount)) / \(formatNumber(model.totalCount)) 次")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                Divider()

                HStack {
                    Text("已用: \(formatNumber(model.usageCount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("重置: \(model.remainsTimeFormatted)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("暂无数据")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
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
