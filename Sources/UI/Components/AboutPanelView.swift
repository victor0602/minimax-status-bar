import AppKit
import SwiftUI

struct AboutPanelView: View {
    @Binding var prefersAutomaticUpdateInstall: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let icon = NSImage(named: "StatusBarIcon") {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .opacity(0.85)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("MiniMax Status Bar")
                        .font(.system(size: 12, weight: .semibold))
                    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                    Text("v\(currentVersion) · macOS 13.0+")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Text("为重度使用 MiniMax Token Plan 的开发者而生。菜单栏一眼感知配额，零配置，零打扰。")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Toggle(isOn: $prefersAutomaticUpdateInstall) {
                Text("发现新版本时自动下载并安装")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .toggleStyle(.checkbox)

            Text("与菜单栏「更新」相同流程；安装在「应用程序」时，替换文件可能需要输入密码。关闭后仍会通过系统通知提醒你。")
                .font(.system(size: 9))
                .foregroundColor(Color(nsColor: .quaternaryLabelColor))
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                aboutLink(
                    icon: "doc.text",
                    title: "MiniMax Token Plan 控制台",
                    url: "https://platform.minimaxi.com/user-center/payment/token-plan"
                )
                aboutLink(
                    icon: "curlybraces",
                    title: "GitHub 源码",
                    url: "https://github.com/victor0602/minimax-status-bar"
                )
                aboutLink(
                    icon: "arrow.down.circle",
                    title: "检查更新",
                    url: "https://github.com/victor0602/minimax-status-bar/releases/latest"
                )
            }

            Text("MIT License · © \(Calendar.current.component(.year, from: Date())) Victor")
                .font(.system(size: 9))
                .foregroundColor(Color(nsColor: .quaternaryLabelColor))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
        }
        .padding(14)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 2)
    }

    private func aboutLink(icon: String, title: String, url: String) -> some View {
        Button(action: {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .frame(width: 14)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
        }
        .buttonStyle(.plain)
    }
}
