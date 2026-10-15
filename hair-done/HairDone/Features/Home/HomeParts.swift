import SwiftUI

// The pieces Home is built from, in the luxe language on the former layout, with the shared tokens.
// See docs/design/mockups/06-home-former-luxe.png and 07-home-former-luxe-scrolled.png.
// Other screens may reuse `HomePhoto`, `HomePortraitTile`, `HomeProRow` and `HomeNextUpCard`.

// MARK: - Photo

/// A work photo that fills its frame, cropped, at the photo radius. With no photo of hers, the
/// neutral ground and an outline glyph: never a bundled photo standing in for her work.
struct HomePhoto: View {
    var item: WorkItem?
    var cornerRadius: CGFloat = Radius.photo

    var body: some View {
        Group {
            if let item {
                WorkTile(item: item, cornerRadius: 0)
            } else {
                NoPhotoTile()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Where a photo would be, when there isn't one: `photoGround` with an outline glyph.
struct NoPhotoTile: View {
    var symbol: String = "photo"

    var body: some View {
        ZStack {
            Palette.photoGround
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .light))
                .foregroundStyle(Palette.inkSoft)
        }
        .accessibilityHidden(true)
    }
}

/// Bundled art for moments that aren't anyone's work: the category tiles, the welcome screen and
/// the location ask. Never captioned with a name. Drawn straight from the bundle, so it doesn't
/// depend on how `WorkTile` treats items with no URL on the live backend.
struct MarketingPhoto: View {
    var category: Category
    var seed: Int

    var body: some View {
        GeometryReader { geo in
            Group {
                if let image = BundledWork.image(for: category, seed: seed) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Rectangle().fill(Placeholder.gradient(seed: seed))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }
}

extension Pro {
    /// Her pinned photo, else her first, else her own avatar. Nil when she has none of those:
    /// callers show `NoPhotoTile`, never a bundled photo presented as hers.
    var homeCover: WorkItem? {
        if let pick = work.first(where: { $0.isPinned }) ?? work.first { return pick }
        if let avatarURL {
            return WorkItem(id: "avatar_\(id)", category: primaryCategory, caption: displayName, seed: seed, imageURL: avatarURL)
        }
        return nil
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

/// The photo each category tile uses: a bundled photo picked by a fixed seed, and a crop. Marketing
/// art for the word under it, not anyone's work, so it's fine on the live backend.
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
        let art = HomeCategoryPhoto.item(for: category)
        return Button {
            Haptics.selection()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                MarketingPhoto(category: art.category, seed: art.seed)
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

/// Her next booking as an ink block: the pro's photo for it, a status dot and eyebrow, the serif
/// what-and-who line and when and where. Opens the booking. The one Next up: Home and Bookings both use it.
struct HomeNextUpCard: View {
    var booking: Booking
    var pro: Pro?
    var action: () -> Void

    /// "BIAB and 1 more with Kiara"; just the services while her card hasn't loaded.
    private var title: String {
        if let pro { return booking.cardTitle(proName: pro.firstName) }
        guard let first = booking.services.first else { return "Your booking" }
        let rest = booking.services.count - 1
        return rest > 0 ? "\(first.name) and \(rest) more" : first.name
    }

    private var isLive: Bool { booking.isToday && booking.status.isActiveDay }

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 0) {
                HomePhoto(item: booking.coverItem(pro: pro), cornerRadius: 0)
                    .frame(width: 84)
                    .frame(maxHeight: .infinity)
                    .clipped()
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        if isLive {
                            LiveDot(color: dotColor, size: 5)
                        } else {
                            Circle().fill(dotColor).frame(width: 5, height: 5)
                        }
                        Text("Next up · \(booking.status.label)")
                            .eyebrowStyle(color: Palette.onInkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityHidden(true)
                    Text(title)
                        .font(HDFont.nameBar)
                        .foregroundStyle(Palette.onInk)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(booking.whenWhereLine)
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.onInkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, Space.l)
                .padding(.vertical, 14)
                Spacer(minLength: Space.s)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Palette.onInkSoft)
                    .padding(.trailing, Space.l)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 104)
            .background(Palette.inkGround)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Palette.onInk.opacity(0.10), lineWidth: 0.5)
            )
        }
        .buttonStyle(PressLift(scale: 0.985))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next up. \(title), \(booking.whenWhereLine), \(booking.status.label)")
        .accessibilityHint("Opens the booking")
        .accessibilityAddTraits(.isButton)
    }

    /// Status dot on ink: warn while it's waiting on her, success once it's on, soft for the rest.
    private var dotColor: Color {
        switch booking.status {
        case .requested: return Palette.warn
        case .confirmed, .onHerWay, .arrived, .inProgress, .done, .paid: return Palette.success
        default: return Palette.onInkSoft
        }
    }
}
