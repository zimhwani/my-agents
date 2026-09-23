import SwiftUI

/// "4.9 · 212 reviews" with one honey star. The compact form for cards.
struct RatingLine: View {
    var rating: Double
    var count: Int
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.honey)
            Text(rating.ratingLabel).font(HDFont.subStrong).foregroundStyle(Palette.ink)
            if !compact {
                Text("·").foregroundStyle(Palette.inkFaint)
                Text(count == 1 ? "1 review" : "\(count) reviews").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rated \(rating.ratingLabel) out of 5 from \(count) reviews")
    }
}

/// Five stars, read-only, for reviews.
struct StarsRow: View {
    var rating: Int
    var size: CGFloat = 12
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(i <= rating ? Palette.honey : Palette.line)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rating) out of 5 stars")
    }
}

/// Tappable stars for rating. Each fills with honey and bounces.
struct StarPicker: View {
    @Binding var rating: Int
    var size: CGFloat = 40

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { i in
                Button {
                    Haptics.light()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { rating = i }
                } label: {
                    Image(systemName: i <= rating ? "star.fill" : "star")
                        .font(.system(size: size, weight: .medium))
                        .foregroundStyle(i <= rating ? Palette.honey : Palette.line)
                        .scaleEffect(i == rating ? 1.15 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(i) star\(i == 1 ? "" : "s")")
                .accessibilityAddTraits(i <= rating ? .isSelected : [])
            }
        }
    }
}
