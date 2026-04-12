import SwiftUI

struct MenuContentView: View {
    let quotaState: QuotaState
    let onRefresh: () -> Void
    var onOpenSettings: () -> Void = {}

    var body: some View {
        DetailView(quotaState: quotaState, onRefresh: onRefresh, onOpenSettings: onOpenSettings)
    }
}
