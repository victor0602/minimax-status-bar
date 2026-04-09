import SwiftUI

struct MenuContentView: View {
    let quotaState: QuotaState
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            CompactView(quotaState: quotaState, onRefresh: onRefresh)

            Divider()

            DetailView(quotaState: quotaState, onRefresh: onRefresh)
        }
        .frame(width: 300)
    }
}
