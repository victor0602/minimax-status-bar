import AppKit
import SwiftUI

/// Calm first-run / zero-config guidance (not an error dump).
@MainActor
struct SetupGuidanceView: View {
    let reason: SetupReason
    let onRetry: () -> Void

    @State private var detectedKey: String = ""
    @State private var pastedKey: String = ""

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
                stepRow(number: 3, text: "实时校验仅用于格式检查；点击「重新检测」后会以最新配置重新连接")
            }

            HStack(spacing: 10) {
                shortcutBadge("⌘R", "刷新")
                shortcutBadge("⌘,", "设置")
                shortcutBadge("⌘Q", "退出")
            }

            VStack(alignment: .leading, spacing: 8) {
                keyStatusSection(title: "当前检测到的 Key", key: detectedKey)
                Divider().opacity(0.5)
                VStack(alignment: .leading, spacing: 6) {
                    Text("粘贴 Key 以实时校验格式（不保存）")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    SecureField("Token Plan API Key（sk-cp-…）", text: $pastedKey)
                        .textFieldStyle(.roundedBorder)
                    keyValidationLine(for: pastedKey)
                }
            }
            .padding(UISpec.cardCornerRadius)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: UISpec.cardCornerRadius))

            VStack(spacing: 8) {
                Button(action: {
                    refreshDetectedKey()
                    onRetry()
                }) {
                    Text("重新检测密钥")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderless)
                .contentShape(Rectangle())
                .background(Color.accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: UISpec.buttonCornerRadius))

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
        .padding(UISpec.panelCornerRadius)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: UISpec.cardCornerRadius))
        .padding(.horizontal, UISpec.contentVerticalPadding + 2)
        .padding(.top, 4)
        .onAppear {
            refreshDetectedKey()
        }
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

    private func shortcutBadge(_ keys: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
        .background(Color.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: UISpec.buttonCornerRadius))
    }

    private func refreshDetectedKey() {
        detectedKey = APIKeyService.resolve()
    }

    private func maskedKeySummary(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "（未检测到）" }
        let prefix = String(trimmed.prefix(10))
        let suffix = String(trimmed.suffix(4))
        return "\(prefix)…\(suffix)（\(trimmed.count) chars）"
    }

    private func keyStatusSection(title: String, key: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Text(maskedKeySummary(key))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary.opacity(0.9))
            keyValidationLine(for: key)
        }
    }

    @ViewBuilder
    private func keyValidationLine(for key: String) -> some View {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Text("未输入：Token Plan Key 通常以 sk-cp- 开头，长度应 ≥ 40")
                .font(.system(size: 10))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
        } else {
            let result = APIKeyService.validateForQuotaAPI(trimmed)
            switch result {
            case .valid:
                Text("✅ 格式有效（Token Plan Key）")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            case .nonTokenPlanKey:
                Text("⚠️ 检测到普通 API Key（sk-），请换成 Token Plan 专用 Key（sk-cp-）")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            case .invalidFormat:
                Text("❌ 格式不正确或过短（需要前缀 + 长度 ≥ 40）")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            case .missing:
                Text("未输入：Token Plan Key 通常以 sk-cp- 开头，长度应 ≥ 40")
                    .font(.system(size: 10))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
        }
    }
}
