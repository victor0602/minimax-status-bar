import SwiftUI

// Type-erased platform-specific style appliers
// glassEffect is only available in macOS 26+ SDK; if #available lets the compiler
// know the branch is conditionally compiled, avoiding "no member glassEffect" errors
// on older SDKs where the method simply doesn't exist.

@MainActor
final class GlassEffectApplier: @unchecked Sendable {
    static let shared = GlassEffectApplier()
    private init() {}

    @available(macOS 26.0, *)
    @MainActor
    private func applyGlass(to view: some View) -> some View {
        view.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    func apply(to view: some View) -> some View {
        if #available(macOS 26.0, *) {
            applyGlass(to: view)
        } else {
            view.background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

@MainActor
final class ButtonStyleApplier: @unchecked Sendable {
    static let shared = ButtonStyleApplier()
    private init() {}

    @available(macOS 26.0, *)
    @MainActor
    private func applyGlassButton(to view: some View) -> some View {
        view.glassEffect(.regular.interactive())
    }

    @MainActor
    private func applyFallbackButton(to view: some View) -> some View {
        view.background(Color.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    func apply(to view: some View) -> some View {
        if #available(macOS 26.0, *) {
            applyGlassButton(to: view)
        } else {
            applyFallbackButton(to: view)
        }
    }
}

@MainActor
final class CardStyleApplier: @unchecked Sendable {
    static let shared = CardStyleApplier()
    private init() {}

    @available(macOS 26.0, *)
    @MainActor
    private func applyGlassCard(to view: some View) -> some View {
        view.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    @MainActor
    private func applyFallbackCard(to view: some View) -> some View {
        view.background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    func apply(to view: some View) -> some View {
        if #available(macOS 26.0, *) {
            applyGlassCard(to: view)
        } else {
            applyFallbackCard(to: view)
        }
    }
}
