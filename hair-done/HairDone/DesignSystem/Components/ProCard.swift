import SwiftUI
import CoreLocation

/// The pro card used on Home and in lists: cover work, avatar, name, specialty, stars, distance, from-price.
struct ProCard: View {
    var pro: Pro
    var distanceKm: Double? = nil
    var nextFree: String? = nil
    var compact = false
    var onTap: () -> Void

    var body: some View {
        Button(action: { Haptics.light(); onTap() }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 2) {
                    ForEach(Array(pro.work.prefix(compact ? 2 : 3)), id: \.id) { item in
                        // Share the width equally. An `.aspectRatio(.fill)` here made the row wider than
                        // the screen, which pushed the whole Home page off its left edge.
                        WorkTile(item: item, cornerRadius: 0)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: compact ? 130 : 176)
                .clipped()
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: Radius.card, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: Radius.card, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if let nextFree {
                        Text(nextFree)
                            .font(HDFont.label)
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Palette.paper.opacity(0.92), in: Capsule())
                            .padding(10)
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(pro.displayName).font(HDFont.name).foregroundStyle(Palette.ink)
                            if pro.isVerified { VerifiedBadge(compact: true) }
                        }
                        Text(pro.specialtyLine).font(HDFont.sub).foregroundStyle(Palette.inkSoft).lineLimit(1)
                        HStack(spacing: 8) {
                            RatingLine(rating: pro.rating, count: pro.reviewCount)
                            if let distanceKm {
                                Text("·").foregroundStyle(Palette.inkFaint)
                                Text(distanceKm.distanceLabel).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("from").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                        Text(Money.format(pro.cheapestServiceCents)).font(HDFont.priceLarge).foregroundStyle(Palette.ink)
                    }
                }
                .padding(Space.cardPadding)
            }
            .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
        }
        .buttonStyle(PressLift(scale: 0.985))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pro.displayName), \(pro.specialtyLine), rated \(pro.rating.ratingLabel), from \(Money.format(pro.cheapestServiceCents))")
        .accessibilityHint("Opens her profile")
    }
}

/// Small horizontal pro tile for the "Who's free" strip.
struct ProMiniTile: View {
    var pro: Pro
    var line: String
    var onTap: () -> Void

    var body: some View {
        Button(action: { Haptics.light(); onTap() }) {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    if let first = pro.work.first { WorkTile(item: first, cornerRadius: Radius.tile) }
                    else { Palette.tint(pro.primaryCategory) }
                }
                .frame(width: 150, height: 188)
                .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                Text(pro.firstName).font(HDFont.name).foregroundStyle(Palette.ink)
                Text(line).font(HDFont.caption).foregroundStyle(Palette.inkSoft).lineLimit(2)
            }
            .frame(width: 150, alignment: .leading)
        }
        .buttonStyle(PressLift())
        .accessibilityLabel("\(pro.firstName), \(line)")
    }
}
