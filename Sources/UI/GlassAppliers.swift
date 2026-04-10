import SwiftUI

// Platform-specific style appliers
// glassEffect is only available in macOS 26+ SDK (Xcode 26+).
// Since GitHub Actions uses Xcode 16 (SDK 15.5) which doesn't have glassEffect,
// we use fallback styling for all versions. The glassEffect calls are removed
// to ensure cross-SDK compatibility.

@MainActor
final class GlassEffectApplier: @unchecked Sendable {
    static let shared = GlassEffectApplier()
    private init() {}

    @ViewBuilder
    func apply(to view: some View) -> some View {
        view.background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

@MainActor
final class ButtonStyleApplier: @unchecked Sendable {
    static let shared = ButtonStyleApplier()
    private init() {}

    @ViewBuilder
    func apply(to view: some View) -> some View {
        view.background(Color.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

@MainActor
final class CardStyleApplier: @unchecked Sendable {
    static let shared = CardStyleApplier()
    private init() {}

    @ViewBuilder
    func apply(to view: some View) -> some View {
        view.background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}
