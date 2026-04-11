import AppKit
import SwiftUI

/// Calm first-run / zero-config guidance (not an error dump).
@MainActor
struct SetupGuidanceView: View {
    let reason: SetupReason
    let onRetry: () -> Void

    private var title: String {
        switch reason {
        case .missingAPIKey:
            return "连接 MiniMax Token Plan"
        case .invalidTokenPlanKeyFormat:
            return "密钥格式需要调整"
        }
    }

    private var subtitle: String {
        switch reason {
        case .missingAPIKey:
            return "本应用只读用量，不会上传密钥。已自动查找 OpenClaw 与环境变量。"
        case .invalidTokenPlanKeyFormat:
            return "请使用 Token Plan 专用 Key（常见前缀 sk-cp-），与普通 Open Platform Key 不同。"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: reason == .missingAPIKey ? "key.horizontal" : "exclamationmark.shield")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                stepRow(number: 1, text: "在 OpenClaw 或环境变量中配置 MINIMAX_API_KEY（Token Plan）")
                stepRow(number: 2, text: "保存后点击下方「重新检测」，无需重启（若从文件读取已更新）")
                stepRow(number: 3, text: "菜单栏圆点表示主力模型剩余比例，点开可查看各模态")
            }

            VStack(spacing: 8) {
                Button(action: onRetry) {
                    Text("重新检测密钥")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 8) {
                    secondaryButton("打开控制台") {
                        if let url = URL(string: "https://platform.minimaxi.com/user-center/payment/token-plan") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    secondaryButton("OpenClaw 目录") {
                        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".openclaw", isDirectory: true)
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 10)
        .padding(.top, 4)
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Color.secondary.opacity(0.85), in: Circle())
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(Color.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
