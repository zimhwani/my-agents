import SwiftUI
import CoreLocation

/// The pro in a list: her work bleeding edge to edge, then two editorial rows in the gutter.
/// Name and price on one line, specialty and distance on the next, the rating last and quietest.
/// Place it at full width; it applies the screen gutter to its own text.
struct ProCard: View {
    var pro: Pro
    var distanceKm: Double? = nil
    var nextFree: String? = nil
    var compact = false
    var onTap: () -> Void

    var body: some View {
        Button(action: { Haptics.light(); onTap() }) {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(spacing: 2) {
                    ForEach(Array(pro.work.prefix(compact ? 2 : 3)), id: \.id) { item in
                        // Share the width equally. An `.aspectRatio(.fill)` here made the row wider than
                        // the screen, which pushed the whole Home page off its left edge.
                        WorkTile(item: item, cornerRadius: 0)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: compact ? 150 : 210)
                .clipped()

                VStack(alignment: .leading, spacing: 5) {
                    if let nextFree {
                        Text(nextFree).labelStyle()
                    }
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Text(pro.displayName).font(HDFont.name).foregroundStyle(Palette.ink)
                        if pro.isVerified { VerifiedBadge(compact: true) }
                        Spacer(minLength: Space.s)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("from").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                            Text(Money.format(pro.cheapestServiceCents)).font(HDFont.price).foregroundStyle(Palette.ink)
                        }
                    }
                    HStack(spacing: 6) {
                        Text(pro.specialtyLine).font(HDFont.sub).foregroundStyle(Palette.inkSoft).lineLimit(1)
                        if let distanceKm {
                            Text("·").font(HDFont.sub).foregroundStyle(Palette.inkFaint)
                            Text(distanceKm.distanceLabel).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        }
                    }
                    RatingLine(rating: pro.rating, count: pro.reviewCount)
                        .padding(.top, 1)
                }
                .screenGutter()
            }
        }
        .buttonStyle(PressLift(scale: 0.99))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pro.displayName), \(pro.specialtyLine), rated \(pro.rating.ratingLabel), from \(Money.format(pro.cheapestServiceCents))")
        .accessibilityHint("Opens her profile")
    }
}

/// Small portrait tile for the "Who's free" strip and favourites. The photo is the tile;
/// her name sits under it in the serif. Nothing on the photo.
struct ProMiniTile: View {
    var pro: Pro
    var line: String
    var onTap: () -> Void

    var body: some View {
        Button(action: { Haptics.light(); onTap() }) {
            VStack(alignment: .leading, spacing: Space.s) {
                Group {
                    if let first = pro.work.first {
                        WorkTile(item: first, cornerRadius: Radius.tile)
                    } else {
                        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                            .fill(Placeholder.gradient(seed: pro.seed))
                    }
                }
                .frame(width: 150, height: 188)
                Text(pro.firstName).font(HDFont.name).foregroundStyle(Palette.ink)
                Text(line).font(HDFont.caption).foregroundStyle(Palette.inkSoft).lineLimit(2)
            }
            .frame(width: 150, alignment: .leading)
        }
        .buttonStyle(PressLift())
        .accessibilityLabel("\(pro.firstName), \(line)")
    }
}
