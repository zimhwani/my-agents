import SwiftUI

// The pieces Home is built from: the hero, the photo tiles and rows, and the type and colour
// Home uses on top of the design system. See docs/design/mockups/01-home.html and 02-home-scrolled.html.

// MARK: - Type

/// Home's sizes, taken from the approved mockups. Serif is New York; every size scales with Dynamic Type.
enum HomeFont {
    /// The hd. nd. mark over the hero and in the bar. A logo, so it doesn't scale.
    static let markSize: CGFloat = 22
    /// 28 regular serif: "Who's free today", "Near you".
    static let section = Font.system(.title, design: .serif)
    /// 24 regular serif: names under the "Who's free" photos.
    static var railName: Font { scaledSerif(24, relativeTo: .title2) }
    /// 28 regular serif: names under the full-width "Near you" photos.
    static var nearName: Font { scaledSerif(28, relativeTo: .title1) }
    /// 17 regular serif: the word under a category photo.
    static let category = Font.system(.body, design: .serif)
    /// 13: the facts line on the hero.
    static let heroFacts = Font.system(.footnote).monospacedDigit()
    /// 17 SF with even digits: "$60".
    static let price = Font.system(.body).monospacedDigit()

    private static func scaledSerif(_ size: CGFloat, relativeTo style: UIFont.TextStyle) -> Font {
        Font.system(size: UIFontMetrics(forTextStyle: style).scaledValue(for: size), weight: .regular, design: .serif)
    }
}

/// Fixed colours for type and scrims over photos. They stay the same in dark mode because the photo does.
enum HomeInk {
    /// Paper type on a photo.
    static let paper = Color(hex: 0xFBF7F2)
    /// The ink the scrims are made of.
    static let scrim = Color(hex: 0x241A16)
    /// Behind a photo that hasn't got one yet.
    static let photoGround = Palette.dyn(light: 0xCBBFB2, dark: 0x2E2622)
}

// MARK: - Photo

/// A work photo that fills whatever frame it's given, cropped, with a small radius. Grey ground when there's none.
struct HomePhoto: View {
    var item: WorkItem?
    var cornerRadius: CGFloat = 0

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

/// Dims a touch on press, without scaling. For the hero, which is too big to lift.
struct HomeQuietPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Hero

/// Where the hero's bottom edge is on screen, so the top bar knows when to turn solid.
struct HomeHeroBottomKey: PreferenceKey {
    static let defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = min(value, nextValue()) }
}

/// Where the top bar's bottom edge is on screen.
struct HomeBarBottomKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// The full-bleed 4:5 photo Home opens on, with the cover line over a bottom scrim.
/// The photo settles from 1.03 to 1 over four seconds and the words fade in after it. Under Reduce Motion, neither moves.
struct HomeHero: View {
    var item: WorkItem?
    var eyebrow: String
    var headline: String?
    var facts: String?
    var accessibilityText: String
    var onTap: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false
    @State private var copyShown = false

    var body: some View {
        Group {
            if let onTap {
                Button {
                    Haptics.light()
                    onTap()
                } label: {
                    picture
                }
                .buttonStyle(HomeQuietPress())
                .accessibilityHint("Opens her profile")
            } else {
                picture
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: HomeHeroBottomKey.self, value: geo.frame(in: .global).maxY)
            }
        }
        .onAppear(perform: settle)
    }

    private var picture: some View {
        Color.clear
            .aspectRatio(0.8, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                HomePhoto(item: item)
                    .scaleEffect(settled ? 1 : 1.03)
            }
            .overlay(alignment: .top) {
                LinearGradient(colors: [HomeInk.scrim.opacity(0.42), HomeInk.scrim.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(stops: [
                    .init(color: HomeInk.scrim.opacity(0), location: 0),
                    .init(color: HomeInk.scrim.opacity(0.30), location: 0.4),
                    .init(color: HomeInk.scrim.opacity(0.62), location: 1)
                ], startPoint: .top, endPoint: .bottom)
                .frame(height: 250)
            }
            .clipped()
            .overlay(alignment: .bottomLeading) { copy }
            .contentShape(Rectangle())
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow)
                .font(HDFont.eyebrow)
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(HomeInk.paper.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let headline {
                Text(headline)
                    .font(HDFont.display)
                    .tracking(-0.4)
                    .foregroundStyle(HomeInk.paper)
                    .fixedSize(horizontal: false, vertical: true)
                    // Narrow enough that "Kiara is free from 5." breaks after "free", as in the mockup.
                    .frame(maxWidth: 270, alignment: .leading)
                    .padding(.top, 10)
            }
            if let facts {
                Text(facts)
                    .font(HomeFont.heroFacts)
                    .foregroundStyle(HomeInk.paper.opacity(0.9))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.gutter)
        .padding(.bottom, 22)
        .opacity(copyShown ? 1 : 0)
        .allowsHitTesting(false)
    }

    private func settle() {
        guard !settled else { return }
        if reduceMotion {
            settled = true
            copyShown = true
            return
        }
        withAnimation(.easeOut(duration: 4)) { settled = true }
        withAnimation(.easeOut(duration: 0.6).delay(0.3)) { copyShown = true }
    }
}

// MARK: - Portrait tile

/// A 4:5 photo with the name in serif under it and one quiet line. Nothing on the photo.
/// 300pt wide for "Who's free", smaller for "Book again" and "Favourites".
struct HomePortraitTile: View {
    var item: WorkItem?
    var width: CGFloat
    var title: String
    var line: String
    var titleFont: Font
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HomePhoto(item: item, cornerRadius: 2)
                    .frame(width: width, height: (width * 1.25).rounded())
                Text(title)
                    .font(titleFont)
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

/// The photo each category tile uses: a bundled work photo picked by a fixed seed, and a crop from the mockup.
enum HomeCategoryPhoto {
    static func item(for category: Category) -> WorkItem {
        // Seeds are chosen so BundledWork lands on the photo the mockup uses. Makeup borrows
        // work-thelot-2 (a bride having her makeup done), which is the photo in the approved mockup.
        switch category {
        case .hair:   return make(category, source: .hair, seed: 1)     // work-hair-3
        case .nails:  return make(category, source: .nails, seed: 3)    // work-nails-1
        case .makeup: return make(category, source: .theLot, seed: 2)   // work-thelot-2
        case .lashes: return make(category, source: .lashes, seed: 2)   // work-lashes-2
        case .brows:  return make(category, source: .brows, seed: 2)    // work-brows-2
        case .theLot: return make(category, source: .theLot, seed: 4)   // work-thelot-4
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

/// A 128pt photo of that kind of work with the word under it in serif. No tint, no icon.
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
                HomePhoto(item: HomeCategoryPhoto.item(for: category))
                    .scaleEffect(zoom.scale, anchor: zoom.anchor)
                    .frame(width: 128, height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                Text(category.label)
                    .font(HomeFont.category)
                    .underline(isSelected)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .padding(.top, 8)
            }
            .frame(width: 128, alignment: .leading)
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

// MARK: - Near you

/// One pro per screen width: a full-bleed 4:5 photo you can swipe through her first three pieces of work,
/// then her name in serif, the facts, the rating and the price. No card, no avatar, nothing on the photo but the page dots.
struct HomeNearYouItem: View {
    var pro: Pro
    /// "Free from 5 pm", shown small above her name. Nil when she isn't free that day.
    var eyebrow: String?
    /// "Nail tech · St Kilda · 13 km"
    var facts: String
    var onOpen: () -> Void

    @State private var page = 0

    private var photos: [WorkItem] { Array(pro.work.prefix(3)) }
    private var price: String { Money.format(pro.cheapestServiceCents) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(0.8, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay { gallery }
                .clipped()
                .overlay(alignment: .bottom) { dots }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(photos.count > 1 ? "\(pro.firstName)'s work, \(photos.count) photos" : "\(pro.firstName)'s work")
                .accessibilityHint("Opens her profile")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onOpen() }

            Button {
                Haptics.light()
                onOpen()
            } label: {
                details
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
            .accessibilityHint("Opens her profile")
            .accessibilityAddTraits(.isButton)
        }
    }

    @ViewBuilder
    private var gallery: some View {
        if photos.count > 1 {
            TabView(selection: $page) {
                ForEach(0..<photos.count, id: \.self) { i in
                    photoPage(photos[i]).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        } else {
            photoPage(photos.first)
        }
    }

    private func photoPage(_ item: WorkItem?) -> some View {
        HomePhoto(item: item)
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.light()
                onOpen()
            }
    }

    @ViewBuilder
    private var dots: some View {
        if photos.count > 1 {
            HStack(spacing: 6) {
                ForEach(0..<photos.count, id: \.self) { i in
                    Circle()
                        .fill(HomeInk.paper.opacity(i == page ? 1 : 0.5))
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.bottom, 12)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let eyebrow {
                Text(eyebrow)
                    .font(HDFont.eyebrow)
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.bottom, 2)
            }
            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                Text(pro.firstName)
                    .font(HomeFont.nearName)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: Space.s)
                Text(price)
                    .font(HomeFont.price)
                    .foregroundStyle(Palette.ink)
            }
            factsText
                .font(HDFont.sub)
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 14)
        .screenGutter()
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// "Nail tech · St Kilda · 13 km · ★ 4.8 (121)"
    private var factsText: Text {
        let lead = Text(verbatim: facts + " · ")
        let star = Text(Image(systemName: "star.fill")).font(.system(size: 11)).foregroundStyle(Palette.honey)
        let rating = Text(verbatim: " \(pro.rating.ratingLabel) (\(pro.reviewCount))")
        return lead + star + rating
    }

    private var accessibilityText: String {
        var parts = [pro.firstName]
        if let eyebrow { parts.append(eyebrow) }
        parts.append(facts)
        parts.append("rated \(pro.rating.ratingLabel) from \(pro.reviewCount) reviews")
        parts.append("from \(price)")
        return parts.joined(separator: ", ")
    }
}

// MARK: - Row

/// A small 4:5 photo beside her name, facts and price. For search results and "See all".
struct HomeProRow: View {
    var pro: Pro
    var eyebrow: String?
    var facts: String
    var action: () -> Void

    private var price: String { Money.format(pro.cheapestServiceCents) }

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                HomePhoto(item: pro.work.first, cornerRadius: 2)
                    .frame(width: 72, height: 90)
                VStack(alignment: .leading, spacing: 3) {
                    if let eyebrow {
                        Text(eyebrow)
                            .font(HDFont.eyebrow)
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Text(pro.firstName)
                        .font(HDFont.name)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text(facts)
                        .font(HDFont.sub)
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Space.s)
                Text(price)
                    .font(HomeFont.price)
                    .foregroundStyle(Palette.ink)
            }
            .padding(.vertical, Space.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressLift(scale: 0.985))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Opens her profile")
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityText: String {
        var parts = [pro.firstName]
        if let eyebrow { parts.append(eyebrow) }
        parts.append(facts)
        parts.append("rated \(pro.rating.ratingLabel)")
        parts.append("from \(price)")
        return parts.joined(separator: ", ")
    }
}
