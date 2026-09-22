import SwiftUI

/// Initials on a tinted circle. Deterministic colour from the seed. Real photos drop in via `url`.
struct Avatar: View {
    var name: String
    var seed: Int
    var size: CGFloat = 44
    var url: URL? = nil

    var body: some View {
        ZStack {
            Circle().fill(Placeholder.gradient(seed: seed))
            if let url {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: { EmptyView() }
                .clipShape(Circle())
            } else {
                Text(name.initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.ink.opacity(0.75))
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
        .accessibilityHidden(true)
    }
}
