import AppKit
import SwiftUI

struct BottomBarView: View {
    @ObservedObject var updateState: UpdateState
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                exitButton
                Spacer()
                if let release = updateState.latestRelease {
                    updateButton(release)
                }
                launchAtLoginButton
                historyButton
                consoleButton
            }
            versionBar
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func updateButton(_ release: ReleaseInfo) -> some View {
        Button(action: {
            updateState.downloadAndInstall(release)
        }) {
            HStack(spacing: 3) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 10))
                Text("更新 v\(release.version)")
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .ifPlatformButton()
        .foregroundColor(.blue)
    }

    private var launchAtLoginButton: some View {
        Button(action: {
            LaunchAtLoginService.isEnabled.toggle()
        }) {
            Image(systemName: LaunchAtLoginService.isEnabled ? "power.circle.fill" : "power.circle")
                .font(.system(size: 14))
                .foregroundColor(LaunchAtLoginService.isEnabled ? .green : .secondary)
        }
        .buttonStyle(.plain)
        .ifPlatformButton()
        .help(LaunchAtLoginService.isEnabled ? "已开启开机启动" : "开启开机启动")
    }

    private var exitButton: some View {
        Button(action: { onExit() }) {
            HStack(spacing: 4) {
                Image(systemName: "power")
                    .font(.system(size: 10))
                Text("退出")
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .ifPlatformButton()
        .keyboardShortcut("q", modifiers: .command)
    }

    private var consoleButton: some View {
        Button(action: {
            if let url = URL(string: "https://platform.minimaxi.com/user-center/payment/token-plan") {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack(spacing: 3) {
                Text("控制台")
                    .font(.system(size: 11))
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 9))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .ifPlatformButton()
    }

    /// 打开设置窗口并跳转到用量历史标签页
    private var historyButton: some View {
        Button(action: {
            Task { @MainActor in
                (NSApp.delegate as? AppDelegate)?.openSettingsWindow(tab: 2)
            }
        }) {
            HStack(spacing: 3) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 10))
                Text("用量历史")
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .ifPlatformButton()
    }

    private var versionBar: some View {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return HStack(spacing: 6) {
            Text("v\(currentVersion)")
                .font(.system(size: 9))
                .foregroundColor(Color(nsColor: .quaternaryLabelColor))

            if let release = updateState.latestRelease {
                Text("→ v\(release.version) 可用")
                    .font(.system(size: 9))
                    .foregroundColor(.blue.opacity(0.7))
            }

            Spacer()

            Button(action: {
                if let url = URL(string: "https://github.com/victor0602/minimax-status-bar") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "curlybraces")
                        .font(.system(size: 8))
                    Text("GitHub")
                        .font(.system(size: 9))
                }
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
            .buttonStyle(.plain)
            .help("在 GitHub 上查看源码")
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }
}
