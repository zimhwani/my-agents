import SwiftUI

// The pieces Home is built from, in the luxe language on the former layout, with the shared tokens.
// See docs/design/mockups/06-home-former-luxe.png and 07-home-former-luxe-scrolled.png.
// Other screens may reuse `HomePhoto`, `HomePortraitTile`, `HomeProRow` and `HomeNextUpCard`.

// MARK: - Photo

/// A work photo that fills its frame, cropped, at the photo radius.
struct HomePhoto: View {
    var item: WorkItem?
    var cornerRadius: CGFloat = Radius.photo

    var body: some View {
        Group {
            if let item {
                WorkTile(item: item, cornerRadius: 0)
            } else {
                Palette.photoGround
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
                    .font(HDFont.nameSmall)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                Text(line)
                    .font(HDFont.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
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
/// Selected: the word is underlined and the others step back. That's the whole filter: no chips.
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
                    .clipShape(RoundedRectangle(cornerRadius: Radius.photo, style: .continuous))
                Text(category.label)
                    .font(HDFont.categoryWord)
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
/// Grows with the text: no fixed height.
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
                            .eyebrowStyle()
                            .padding(.bottom, 5)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Text(pro.displayName)
                            .font(HDFont.name)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: Space.xs)
                        if let price {
                            Text(price)
                                .font(HDFont.priceSmall)
                                .foregroundStyle(Palette.ink)
                                .fixedSize()
                        }
                    }
                    Text(pro.specialtyLine)
                        .font(HDFont.sub)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                    factsText
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 3)
                }
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .padding(.bottom, Space.m)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Palette.lineStrong).frame(height: 0.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressLift(scale: 0.985))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Opens her profile")
        .accessibilityAddTraits(.isButton)
    }

    /// "Brunswick · 2.9 km · ☆ 4.9 (86)": an outline star in inkSoft, as on the profile.
    private var factsText: Text {
        let lead = Text(verbatim: "\(pro.suburb) · \(distanceKm.distanceLabel)")
        guard pro.reviewCount > 0 else { return lead }
        let star = Text(Image(systemName: "star")).font(.system(size: 10))
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

// MARK: - Next up

/// Her next booking as an ink block: the pro's photo, status, what and when. Opens the booking.
struct HomeNextUpCard: View {
    var booking: Booking
    var pro: Pro?
    var action: () -> Void

    private var title: String {
        let first = booking.services.first?.name ?? "Booking"
        let rest = booking.services.count - 1
        let what = rest > 0 ? "\(first) and \(rest) more" : first
        if let pro { return "\(what) with \(pro.firstName)" }
        return what
    }

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 0) {
                HomePhoto(item: pro?.homeCover, cornerRadius: 0)
                    .frame(width: 76)
                    .frame(maxHeight: .infinity)
                    .clipped()
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(booking.status == .requested ? Palette.onInkSoft : Palette.onInk)
                            .frame(width: 5, height: 5)
                            .accessibilityHidden(true)
                        Text("Next up · " + booking.status.label)
                            .eyebrowStyle(color: Palette.onInkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(title)
                        .font(HDFont.nameBar)
                        .foregroundStyle(Palette.onInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(booking.start.friendlyDayTime)
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.onInkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 16)
                .padding(.vertical, 14)
                Spacer(minLength: Space.s)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Palette.onInkSoft)
                    .padding(.trailing, 16)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 96)
            .background(Palette.inkGround)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Palette.onInk.opacity(0.10), lineWidth: 0.5)
            )
        }
        .buttonStyle(PressLift(scale: 0.985))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the booking")
    }
}
