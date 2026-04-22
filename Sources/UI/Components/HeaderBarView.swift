import SwiftUI
import AppKit

struct HeaderBarView: View {
    let quotaState: QuotaState
    let now: Date
    var isShowingSettings: Bool = false
    var settingsBreadcrumb: String? = nil
    let onRefresh: () -> Void
    var onOpenSettings: () -> Void = {}
    var onBackFromSettings: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MiniMax")
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitleText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            if quotaState.isLoading, !isShowingSettings {
                ProgressView().scaleEffect(0.6)
            }
            settingsButton
            if !isShowingSettings {
                refreshButton
            }
        }
        .padding(.horizontal, UISpec.contentHorizontalPadding)
        .padding(.vertical, UISpec.contentVerticalPadding)
    }

    private var subtitleText: String {
        if isShowingSettings {
            if let settingsBreadcrumb, !settingsBreadcrumb.isEmpty {
                return settingsBreadcrumb
            }
            return "偏好与用量历史 / 通用"
        }
        if quotaState.setupReason != nil {
            return "用量感知 · 待连接"
        }
        if let updated = quotaState.lastUpdatedAt {
            return "Token Plan 用量 · 最后更新 \(PopoverChrome.relativeTime(updated, now: now))"
        }
        return "Token Plan 用量"
    }

    private var settingsButton: some View {
        Button(action: {
            if isShowingSettings {
                onBackFromSettings()
            } else {
                onOpenSettings()
            }
        }) {
            Image(systemName: isShowingSettings ? "chevron.left" : "gearshape")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                .frame(width: 30, height: 28)
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
        .ifPlatformButton()
        .help(isShowingSettings ? "返回主页面" : "设置（⌘,）")
    }

    private var refreshButton: some View {
        Button(action: { onRefresh() }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 30, height: 28)
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
        .ifPlatformButton()
        .keyboardShortcut("r", modifiers: .command)
        .help("刷新数据（⌘R）")
    }
}
