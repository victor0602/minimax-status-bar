import SwiftUI

struct DownloadingUpdateOverlayView: View {
    @ObservedObject var updateState: UpdateState

    var body: some View {
        Group {
            if updateState.isDownloading {
                ZStack {
                    Color.black.opacity(0.5)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(spacing: 12) {
                        if updateState.installPhase == "下载中" {
                            Text("正在下载更新...")
                                .font(.system(size: 13, weight: .medium))
                            ProgressView(value: updateState.downloadProgress)
                                .frame(width: 200)
                            Text("\(Int(updateState.downloadProgress * 100))%")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Button("取消") {
                                updateState.cancelDownload()
                            }
                            .font(.system(size: 11))
                            .buttonStyle(.plain)
                            .ifPlatformButton()
                        } else if updateState.installPhase == "安装中" {
                            Text("正在安装更新...")
                                .font(.system(size: 13, weight: .medium))
                            ProgressView()
                                .frame(width: 200)
                            Text("请稍候")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else if updateState.installPhase == "重启中" {
                            Text("更新完成，正在重启...")
                                .font(.system(size: 13, weight: .medium))
                            ProgressView()
                                .frame(width: 200)
                        }
                    }
                    .padding(24)
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .transition(.opacity)
            }
        }
    }
}
