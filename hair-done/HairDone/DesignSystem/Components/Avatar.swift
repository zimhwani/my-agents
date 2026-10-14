import SwiftUI

/// A round face for Inbox and the thread header, the one place a circle earns its keep.
/// Pros: pass `photo` (her cover) and it's cropped into the circle. Clients: initials in serif
/// regular on a quiet oat ground. Real photos drop in via `url`. Elsewhere, use her cover photo
/// at 2pt corners, not an avatar.
struct Avatar: View {
    var name: String
    var seed: Int
    var size: CGFloat = 44
    var url: URL? = nil
    /// Her cover, cropped to the circle. Wins over initials; `url` wins over both.
    var photo: WorkItem? = nil

    var body: some View {
        ZStack {
            // Oat, not candy: every avatar the same quiet surface so the photos carry the colour.
            Circle().fill(Palette.dyn(light: 0xEDE4D8, dark: 0x2E2622))
            if let url {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: { EmptyView() }
            } else if let photo {
                WorkTile(item: photo, cornerRadius: 0)
            } else {
                Text(name.initials)
                    .font(.system(size: size * 0.38, weight: .regular, design: .serif))
                    .foregroundStyle(Palette.ink)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Palette.lineStrong, lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}

#Preview("Avatar") {
    HStack(spacing: 12) {
        Avatar(name: "Tash Nguyen", seed: 1)
        Avatar(name: "Kiara M", seed: 2, photo: WorkItem(id: "p", category: .nails, caption: "Kiara", seed: 3))
        Avatar(name: "Kiara M", seed: 2, size: 28)
    }
    .padding(20)
    .paperBackground()
}
