import SwiftUI

/// Cached data age when API fails but disk cache exists.
struct OfflineBannerView: View {
    let quotaState: QuotaState
    let now: Date

    var body: some View {
        Group {
            if quotaState.lastError != nil, !quotaState.hasData, quotaState.hasCachedData, let cachedAt = quotaState.cachedAt {
                let ageMinutes = Int(now.timeIntervalSince(cachedAt) / 60)
                let ageText = ageMinutes < 1 ? "刚刚" : "\(ageMinutes) 分钟前"
                HStack(spacing: 4) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 9))
                    Text("数据来自 \(ageText)，当前无法连接")
                        .font(.system(size: 10))
                }
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            }
        }
    }
}
