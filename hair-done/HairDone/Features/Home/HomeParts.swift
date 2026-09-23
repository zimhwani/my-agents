import SwiftUI

// The pieces Home is built from, in the luxe language on the former layout.
// See docs/design/mockups/06-home-former-luxe.png and 07-home-former-luxe-scrolled.png.

// MARK: - Type and colour

/// Home's sizes, from the mockups. Serif is New York; sizes scale with Dynamic Type.
enum HomeFont {
    /// 40 serif: "Afternoon, Tash."
    static var greeting: Font { scaledSerif(40, relativeTo: .largeTitle) }
    /// 26 serif: "Who's free today", "Near you".
    static var section: Font { scaledSerif(26, relativeTo: .title1) }
    /// 19 serif: a name under a portrait photo.
    static var railName: Font { scaledSerif(19, relativeTo: .title3) }
    /// 22 serif: a name in a Near you row.
    static var rowName: Font { scaledSerif(22, relativeTo: .title2) }
    /// 21 serif: the booking on the Next up card.
    static var nextUp: Font { scaledSerif(21, relativeTo: .title3) }
    /// 16 serif: the word under a category photo.
    static var category: Font { scaledSerif(16, relativeTo: .callout) }
    /// 15 SF with even digits: "from $95".
    static let price = Font.system(.subheadline).monospacedDigit()

    private static func scaledSerif(_ size: CGFloat, relativeTo style: UIFont.TextStyle) -> Font {
        Font.system(size: UIFontMetrics(forTextStyle: style).scaledValue(for: size), weight: .regular, design: .serif)
    }
}

/// Fixed colours. The Next up card is ink in both light and dark mode, like the booking ticket.
enum HomeInk {
    static let ink = Color(hex: 0x241A16)
    static let onInk = Color(hex: 0xF4ECE4)
    static let confirmed = Color(hex: 0x7FA88A)
    /// Behind a photo that hasn't loaded.
    static let photoGround = Palette.dyn(light: 0xCBBFB2, dark: 0x2E2622)
}

/// The eyebrow style: small, medium weight, tracked capitals.
extension View {
    func homeEyebrow() -> some View {
        self.font(HDFont.eyebrow)
            .tracking(1)
            .textCase(.uppercase)
    }
}

// MARK: - Photo

/// A work photo that fills its frame, cropped, with a small radius.
struct HomePhoto: View {
    var item: WorkItem?
    var cornerRadius: CGFloat = 2

    var body: some View {
        Group {
            if let item {
                WorkTile(item: item, cornerRadius: 0)
            } else {
                HomeInk.photoGround
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

extension Pro {
    /// Her pinned photo, else her first, else a bundled one of her kind of work.
    var homeCover: WorkItem {
        work.first(where: { $0.isPinned }) ?? work.first
            ?? WorkItem(id: "cover_\(id)", category: primaryCategory, caption: displayName, seed: seed)
    }
}

// MARK: - Portrait tile

/// A 4:5 photo with the name in serif under it and one quiet line. Nothing on the photo.
struct HomePortraitTile: View {
    var item: WorkItem?
    var width: CGFloat
    var title: String
    var line: String
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HomePhoto(item: item)
                    .frame(width: width, height: (width * 1.25).rounded())
                Text(title)
                    .font(HomeFont.railName)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .padding(.top, 10)
                Text(line)
                    .font(HDFont.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
            .frame(width: width, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressLift(scale: 0.98))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(line)")
        .accessibilityHint("Opens her profile")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Category tile

/// The photo each category tile uses: a bundled work photo picked by a fixed seed, and a crop.
enum HomeCategoryPhoto {
    static func item(for category: Category) -> WorkItem {
        // Makeup borrows work-thelot-2 (a bride having her makeup done); the single makeup photo is weaker.
        switch category {
        case .hair:   return make(category, source: .hair, seed: 1)
        case .nails:  return make(category, source: .nails, seed: 3)
        case .makeup: return make(category, source: .theLot, seed: 2)
        case .lashes: return make(category, source: .lashes, seed: 2)
        case .brows:  return make(category, source: .brows, seed: 2)
        case .theLot: return make(category, source: .theLot, seed: 4)
        }
    }

    /// How far to push in, and towards where, so the work fills the tile.
    static func zoom(for category: Category) -> (scale: CGFloat, anchor: UnitPoint) {
        switch category {
        case .hair:   return (1.15, UnitPoint(x: 0.5, y: 0.3))
        case .nails:  return (1.25, UnitPoint(x: 0.45, y: 0.2))
        case .makeup: return (1.5, UnitPoint(x: 0.45, y: 0.28))
        default:      return (1, .center)
        }
    }

    private static func make(_ category: Category, source: Category, seed: Int) -> WorkItem {
        WorkItem(id: "home-category-\(category.rawValue)", category: source, caption: category.label, seed: seed)
    }
}

/// A 104pt photo of that kind of work with the word under it in serif. No tint, no icon.
/// Selected: the word is underlined and the others step back.
struct HomeCategoryTile: View {
    var category: Category
    var isSelected: Bool
    var isDimmed: Bool
    var action: () -> Void

    var body: some View {
        let zoom = HomeCategoryPhoto.zoom(for: category)
        return Button {
            Haptics.selection()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HomePhoto(item: HomeCategoryPhoto.item(for: category), cornerRadius: 0)
                    .scaleEffect(zoom.scale, anchor: zoom.anchor)
                    .frame(width: 104, height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                Text(category.label)
                    .font(HomeFont.category)
                    .underline(isSelected)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .padding(.top, 8)
            }
            .frame(width: 104, alignment: .leading)
            .opacity(isDimmed ? 0.45 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressLift(scale: 0.97))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.label)
        .accessibilityHint(isSelected ? "Clears the filter" : "Shows \(category.label.lowercased()) pros near you")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}

// MARK: - Near you row

/// A 96 by 120 photo beside her name, what she does, where, and the price. A hairline under the words.
struct HomeProRow: View {
    var pro: Pro
    /// "Free from 5 pm", small above her name. Nil when she isn't free that day.
    var eyebrow: String?
    var distanceKm: Double
    var action: () -> Void

    private var price: String? {
        let cents = pro.cheapestServiceCents
        return cents > 0 ? "from \(Money.format(cents))" : nil
    }

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(alignment: .top, spacing: 16) {
                HomePhoto(item: pro.homeCover)
                    .frame(width: 96, height: 120)
                VStack(alignment: .leading, spacing: 0) {
                    if let eyebrow {
                        Text(eyebrow)
                            .homeEyebrow()
                            .foregroundStyle(Palette.inkSoft)
                            .padding(.bottom, 5)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Text(pro.displayName)
                            .font(HomeFont.rowName)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Spacer(minLength: Space.xs)
                        if let price {
                            Text(price)
                                .font(HomeFont.price)
                                .foregroundStyle(Palette.ink)
                        }
                    }
                    Text(pro.specialtyLine)
                        .font(HDFont.sub)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .padding(.top, 4)
                    factsText
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)
                        .padding(.top, 3)
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(Palette.line)
                        .frame(height: 0.5)
                }
                .frame(height: 131, alignment: .top)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressLift(scale: 0.985))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Opens her profile")
        .accessibilityAddTraits(.isButton)
    }

    /// "Brunswick · 2.9 km · ★ 4.9 (86)"
    private var factsText: Text {
        let lead = Text(verbatim: "\(pro.suburb) · \(distanceKm.distanceLabel)")
        guard pro.reviewCount > 0 else { return lead }
        let star = Text(Image(systemName: "star.fill")).font(.system(size: 10)).foregroundStyle(Palette.honey)
        let rating = Text(verbatim: " \(pro.rating.ratingLabel) (\(pro.reviewCount))")
        return lead + Text(verbatim: " · ") + star + rating
    }

    private var accessibilityText: String {
        var parts = [pro.displayName]
        if let eyebrow { parts.append(eyebrow) }
        parts.append(pro.specialtyLine)
        parts.append("\(pro.suburb), \(distanceKm.distanceLabel)")
        if pro.reviewCount > 0 { parts.append("rated \(pro.rating.ratingLabel) from \(pro.reviewCount) reviews") }
        if let price { parts.append(price) }
        return parts.joined(separator: ", ")
    }
}
