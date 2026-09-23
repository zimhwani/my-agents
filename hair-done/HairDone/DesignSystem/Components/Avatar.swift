import SwiftUI

/// Initials on a tinted circle. Deterministic colour from the seed. Real photos drop in via `url`.
struct Avatar: View {
    var name: String
    var seed: Int
    var size: CGFloat = 44
    var url: URL? = nil

    var body: some View {
        ZStack {
            // Oat, not candy: every avatar the same quiet surface so the photos carry the colour.
            Circle().fill(Palette.dyn(light: 0xEDE4D8, dark: 0x2E2622))
            if let url {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: { EmptyView() }
                .clipShape(Circle())
            } else {
                Text(name.initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.ink.opacity(0.8))
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Palette.line, lineWidth: 1))
        .accessibilityHidden(true)
    }
}
