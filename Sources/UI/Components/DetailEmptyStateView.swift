import SwiftUI

struct DetailEmptyStateView: View {
    let quotaState: QuotaState
    let onRefresh: () -> Void

    var body: some View {
        Group {
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
    }
}
