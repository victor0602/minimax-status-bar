import SwiftUI

struct MenuContentView: View {
    @ObservedObject var appState: AppState
    let onRefresh: () -> Void
    @State private var isDetailExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            CompactView(
                usage: appState.tokenUsage,
                stats: appState.apiStats,
                isLoading: appState.isLoading,
                lastError: appState.lastError
            )

            Divider()

            DetailView(
                usage: appState.tokenUsage,
                stats: appState.apiStats,
                isExpanded: $isDetailExpanded
            )

            Divider()

            HStack {
                Button(action: onRefresh) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(appState.isLoading)

                Spacer()

                Text(lastUpdatedText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
    }

    private var lastUpdatedText: String {
        guard let date = appState.tokenUsage?.updatedAt else {
            return "最后更新: --"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "最后更新: \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}
