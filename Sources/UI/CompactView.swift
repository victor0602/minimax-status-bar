import SwiftUI

struct CompactView: View {
    let usage: TokenUsage?
    let stats: APIStats
    let isLoading: Bool
    let lastError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading {
                HStack {
                    ProgressView()
                    Text("刷新中...")
                }
            } else if let error = lastError {
                Text("错误: \(error)").foregroundColor(.red)
            } else if let usage = usage {
                HStack {
                    Text("Token 使用: \(String(format: "%.0f", usage.usedPercent))%")
                        .font(.headline)
                    Spacer()
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor(for: usage.usedPercent))
                            .frame(width: geometry.size.width * CGFloat(usage.usedPercent / 100), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(formatNumber(usage.usedTokens))/\(formatNumber(usage.totalTokens))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                Divider()

                HStack {
                    Text("调用次数: \(formatNumber(stats.totalCalls))")
                    Spacer()
                    Text("错误率: \(String(format: "%.1f", stats.errorRate * 100))%")
                }
                .font(.caption)
            } else {
                Text("暂无数据")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private func progressColor(for percent: Double) -> Color {
        if percent < 70 { return .green }
        if percent < 90 { return .yellow }
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
