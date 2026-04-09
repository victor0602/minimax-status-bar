import SwiftUI

struct DetailView: View {
    let usage: TokenUsage?
    let stats: APIStats
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Text("详细信息")
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }
            .buttonStyle(.plain)

            if isExpanded, let usage = usage {
                Divider()

                Group {
                    LabeledContent("已用 Token", value: formatNumber(usage.usedTokens))
                    LabeledContent("剩余 Token", value: formatNumber(usage.remainingTokens))
                    LabeledContent("总 Token", value: formatNumber(usage.totalTokens))
                }
                .font(.caption)

                Divider()

                Group {
                    LabeledContent("总调用", value: "\(stats.totalCalls)")
                    LabeledContent("本分钟", value: "\(stats.callsThisMinute)")
                    LabeledContent("成功率", value: String(format: "%.1f%%", (1 - stats.errorRate) * 100))
                    LabeledContent("错误率", value: String(format: "%.1f%%", stats.errorRate * 100))
                    LabeledContent("平均响应", value: String(format: "%.0fms", stats.avgResponseTime))
                }
                .font(.caption)
            }
        }
        .padding()
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
