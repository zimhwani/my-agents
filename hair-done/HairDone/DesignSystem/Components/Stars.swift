import SwiftUI

/// "☆ 4.9 · 212 reviews": an outline star in inkSoft at the text size, as on the profile.
/// Honey is for the rating picker only.
struct RatingLine: View {
    var rating: Double
    var count: Int
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star").font(.system(size: 12, weight: .regular)).foregroundStyle(Palette.inkSoft)
            Text(rating.ratingLabel).font(HDFont.sub).foregroundStyle(Palette.ink)
            if !compact {
                Text("·").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                Text(count == 1 ? "1 review" : "\(count) reviews").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rated \(rating.ratingLabel) out of 5 from \(count) reviews")
    }
}

/// Five stars, read-only, for reviews: filled ink up to the rating, outline inkFaint after.
struct StarsRow: View {
    var rating: Int
    var size: CGFloat = 12
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: size, weight: .regular))
                    .foregroundStyle(i <= rating ? Palette.ink : Palette.inkFaint)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rating) out of 5 stars")
    }
}

/// Tappable stars for rating. Each fills with honey and bounces: the one place honey lives.
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
                        .font(.system(size: size, weight: .light))
                        .foregroundStyle(i <= rating ? Palette.honey : Palette.inkFaint)
                        .scaleEffect(i == rating ? 1.15 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(i) star\(i == 1 ? "" : "s")")
                .accessibilityAddTraits(i <= rating ? .isSelected : [])
            }
        }
    }
}
