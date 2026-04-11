import SwiftUI

// MARK: - Visual policy (Liquid Glass vs CI)
//
// 产品定位是「瞟一眼即知的感知工具」，观感必须可信；但 **CI 与可复现构建** 当前基于较旧 Xcode。
// 在此明确取舍：默认使用与系统协调的 **原生材质 + 圆角**（全版本一致），不把 Liquid Glass 绑在
// 无法在 GitHub Actions 编译的路径上。若未来 CI 升级至带 `glassEffect` 的 SDK，可在此文件用
// `#available` 分支恢复「仅 macOS 26+ 增强」，且保持 13–25 的 fallback 为同一套可信样式。

@MainActor
final class GlassEffectApplier {
    static let shared = GlassEffectApplier()
    private init() {}

    @ViewBuilder
    func apply(to view: some View) -> some View {
        view.background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

@MainActor
final class ButtonStyleApplier {
    static let shared = ButtonStyleApplier()
    private init() {}

    @ViewBuilder
    func apply(to view: some View) -> some View {
        view.background(Color.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

@MainActor
final class CardStyleApplier {
    static let shared = CardStyleApplier()
    private init() {}

    @ViewBuilder
    func apply(to view: some View) -> some View {
        view.background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}
