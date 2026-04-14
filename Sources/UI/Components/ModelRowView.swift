import SwiftUI

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
                    Text("剩余 \(model.remainingPercentForDisplay)%")
                        .font(.caption)
                        .foregroundColor(progressColor(for: model.remainingPercentForDisplay))
                    Text("已用 \(model.intervalConsumedPercent)%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(PopoverChrome.rowExpandSpring) {
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
                        // 确保进度条最小显示 2%，避免完全看不见
                        .frame(width: max(geometry.size.width * CGFloat(model.remainingPercent) / 100, model.remainingPercent > 0 ? 2 : 0), height: 5)
                }
            }
            .frame(height: 5)

            HStack {
                Text("剩余 \(ModelQuota.formatCountForDisplay(model.remainingCount)) / \(ModelQuota.formatCountForDisplay(model.totalCount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("重置: \(model.remainsTimeFormatted)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    Text("本周剩余 \(ModelQuota.formatCountForDisplay(model.weeklyRemainingCount)) / 限额 \(ModelQuota.formatCountForDisplay(model.weeklyTotalCount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("本周已用 \(ModelQuota.formatCountForDisplay(model.weeklyConsumedCount))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, UISpec.contentHorizontalPadding)
        .padding(.vertical, UISpec.contentVerticalPadding)
        .contentShape(Rectangle())
    }

    private func progressColor(for percent: Int) -> Color {
        if percent > 30 { return .green }
        if percent > 10 { return .yellow }
        return .red
    }

}
