import AppKit
import SwiftUI

struct BottomBarView: View {
    @ObservedObject var updateState: UpdateState
    let onExit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            exitButton
            versionLabel
            Spacer()
            if let release = updateState.latestRelease {
                updateButton(release)
            }
            launchAtLoginButton
            consoleButton
        }
        .padding(.horizontal, UISpec.contentHorizontalPadding)
        .padding(.vertical, UISpec.contentVerticalPadding)
    }

    private var versionLabel: some View {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return Text("v\(currentVersion)")
            .font(.system(size: 9))
            .monospacedDigit()
            .foregroundColor(Color(nsColor: .quaternaryLabelColor))
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
            .padding(.horizontal, 8)
            .padding(.vertical, UISpec.compactVerticalPadding - 1)
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
        .ifPlatformButton()
        .foregroundColor(.blue)
        .help("下载并安装 v\(release.version)")
    }

    private var launchAtLoginButton: some View {
        Button(action: {
            LaunchAtLoginService.isEnabled.toggle()
        }) {
            Image(systemName: LaunchAtLoginService.isEnabled ? "power.circle.fill" : "power.circle")
                .font(.system(size: 14))
                .foregroundColor(LaunchAtLoginService.isEnabled ? .green : .secondary)
                .frame(width: 24, height: 22)
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
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
            .padding(.horizontal, 8)
            .padding(.vertical, UISpec.compactVerticalPadding - 1)
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
        .ifPlatformButton()
        .keyboardShortcut("q", modifiers: .command)
        .help("退出（⌘Q）")
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
            .padding(.horizontal, 8)
            .padding(.vertical, UISpec.compactVerticalPadding - 1)
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
        .ifPlatformButton()
        .help("打开 MiniMax Token Plan 控制台")
    }

}
