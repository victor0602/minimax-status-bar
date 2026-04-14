import SwiftUI

struct LastUpdatedLineView: View {
    let lastUpdatedAt: Date
    let now: Date

    var body: some View {
        Text("最后更新：\(PopoverChrome.relativeTime(lastUpdatedAt, now: now))")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, UISpec.contentHorizontalPadding)
            .padding(.bottom, UISpec.compactVerticalPadding)
    }
}
