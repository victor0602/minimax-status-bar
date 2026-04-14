import SwiftUI

struct SkeletonRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var shimmerOn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                bar(120, 12, radius: 4)
                Spacer()
                bar(40, 12, radius: 4)
            }
            bar(nil, 5, radius: 2)
                .frame(maxWidth: .infinity)
            HStack {
                bar(80, 10, radius: 4)
                Spacer()
                bar(60, 10, radius: 4)
            }
        }
        .padding(.horizontal, UISpec.contentHorizontalPadding)
        .padding(.vertical, UISpec.contentVerticalPadding)
        .overlay {
            GeometryReader { geo in
                let w = geo.size.width
                LinearGradient(
                    colors: [
                        .clear,
                        (colorScheme == .dark ? Color.white : Color.black).opacity(0.22),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: w * 0.42)
                .offset(x: shimmerOn ? w * 0.65 : -w * 0.55)
                .animation(.linear(duration: 1.35).repeatForever(autoreverses: false), value: shimmerOn)
            }
            .allowsHitTesting(false)
            .mask(
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        RoundedRectangle(cornerRadius: 4).frame(width: 120, height: 12)
                        Spacer()
                        RoundedRectangle(cornerRadius: 4).frame(width: 40, height: 12)
                    }
                    RoundedRectangle(cornerRadius: 2).frame(height: 5)
                    HStack {
                        RoundedRectangle(cornerRadius: 4).frame(width: 80, height: 10)
                        Spacer()
                        RoundedRectangle(cornerRadius: 4).frame(width: 60, height: 10)
                    }
                }
                .padding(.horizontal, UISpec.contentHorizontalPadding)
                .padding(.vertical, UISpec.contentVerticalPadding)
            )
        }
        .onAppear {
            shimmerOn = true
        }
    }

    private func bar(_ width: CGFloat?, _ height: CGFloat, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color.primary.opacity(0.08))
            .frame(width: width, height: height)
    }
}
