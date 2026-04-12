import SwiftUI

struct HeaderBarView: View {
    let quotaState: QuotaState
    @Binding var showAbout: Bool
    let onRefresh: () -> Void
    var onOpenSettings: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MiniMax")
                        .font(.system(size: 13, weight: .semibold))
                    Button(action: { withAnimation(PopoverChrome.aboutSpring) { showAbout.toggle() } }) {
                        HStack(spacing: 3) {
                            Text(quotaState.setupReason != nil ? "用量感知 · 待连接" : "Token Plan 用量")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Image(systemName: showAbout ? "chevron.up" : "info.circle")
                                .font(.system(size: 8))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        }
                    }
                    .buttonStyle(.plain)
                    .help("关于此应用")
                }
                Spacer()
                HStack(spacing: 6) {
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .help("设置（⌘,）")
                    if quotaState.isLoading {
                        ProgressView().scaleEffect(0.6)
                    }
                    refreshButton
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var refreshButton: some View {
        Button(action: { onRefresh() }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .medium))
                .padding(7)
        }
        .buttonStyle(.plain)
        .ifPlatformButton()
        .keyboardShortcut("r", modifiers: .command)
        .help("刷新数据")
    }
}
