import SwiftUI
import CoreLocation

/// A pro, the luxe way: her cover at 4:5 and 2pt corners, then her name in serif 22, one fact line
/// in SF 15 inkSoft, and the price right-aligned in SF monospaced. No white card, no avatar, no
/// capsule on the photo, no three-photo strip. Prefer Home's `HomeProRow` and `HomePortraitTile`
/// where they fit; this is the full-width version.
struct ProCard: View {
    var pro: Pro
    var distanceKm: Double? = nil
    /// "Free from 5 pm": an eyebrow above her name, never on the photo.
    var nextFree: String? = nil
    /// 3:2 instead of 4:5, for tighter lists.
    var compact = false
    var onTap: () -> Void

    var body: some View {
        Button(action: { Haptics.light(); onTap() }) {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .aspectRatio(compact ? 3.0 / 2.0 : 4.0 / 5.0, contentMode: .fit)
                    .overlay {
                        if let cover = pro.work.first(where: { $0.isPinned }) ?? pro.work.first {
                            WorkTile(item: cover, cornerRadius: 0)
                        } else {
                            Palette.photoGround
                        }
                    }
                    .photoShape()
                if let nextFree {
                    Text(nextFree).eyebrowStyle().padding(.top, Space.m)
                }
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    Text(pro.displayName).font(HDFont.name).foregroundStyle(Palette.ink).lineLimit(1)
                    Spacer(minLength: Space.xs)
                    if pro.cheapestServiceCents > 0 {
                        Text("from \(Money.format(pro.cheapestServiceCents))").font(HDFont.priceSmall).foregroundStyle(Palette.ink)
                    }
                }
                .padding(.top, nextFree == nil ? Space.m : Space.xs)
                Text(factLine).font(HDFont.sub).foregroundStyle(Palette.inkSoft).lineLimit(1).padding(.top, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressLift(scale: 0.985))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pro.displayName), \(pro.specialtyLine), rated \(pro.rating.ratingLabel), from \(Money.format(pro.cheapestServiceCents))")
        .accessibilityHint("Opens her profile")
    }

    /// "Nail tech · Brunswick · 2.9 km · ★ 4.9 (86)"
    private var factLine: String {
        var parts = [pro.specialtyLine]
        if let distanceKm { parts.append(distanceKm.distanceLabel) }
        if pro.reviewCount > 0 { parts.append("★ \(pro.rating.ratingLabel) (\(pro.reviewCount))") }
        return parts.joined(separator: " · ")
    }
}

/// A 150pt portrait tile for a rail: her photo at 4:5 and 2pt corners, first name in serif 19,
/// one SF 13 inkSoft line. Same object as Home's `HomePortraitTile`.
struct ProMiniTile: View {
    var pro: Pro
    var line: String
    var onTap: () -> Void

    var body: some View {
        Button(action: { Haptics.light(); onTap() }) {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if let first = pro.work.first(where: { $0.isPinned }) ?? pro.work.first { WorkTile(item: first, cornerRadius: 0) }
                    else { Palette.photoGround }
                }
                .frame(width: 150, height: 188)
                .photoShape()
                Text(pro.firstName).font(HDFont.nameSmall).foregroundStyle(Palette.ink).lineLimit(1).padding(.top, 10)
                Text(line).font(HDFont.caption).foregroundStyle(Palette.inkSoft).lineLimit(2).padding(.top, 2)
            }
            .frame(width: 150, alignment: .leading)
        }
        .buttonStyle(PressLift(scale: 0.98))
        .accessibilityLabel("\(pro.firstName), \(line)")
    }
}
