import SwiftUI

extension View {
    @ViewBuilder
    func ifPlatformGlass() -> some View {
        GlassEffectApplier.shared.apply(to: self)
    }

    @ViewBuilder
    func ifPlatformButton() -> some View {
        ButtonStyleApplier.shared.apply(to: self)
    }

    @ViewBuilder
    func ifPlatformCard() -> some View {
        CardStyleApplier.shared.apply(to: self)
    }
}
