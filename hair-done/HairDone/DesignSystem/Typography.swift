import SwiftUI

/// The one type scale. Display is the system serif (New York) in **regular** weight; everything
/// else is SF Pro. Money is always SF with monospaced digits, never serif.
/// Every size scales with Dynamic Type, either text-style based or through UIFontMetrics.
///
/// Serif steps: display 40 · title 34 · titleSmall 28 · section 26 · name 22 · nameBar 21 ·
/// nameSmall 19 · quote 19 · categoryWord 16 (and heroName 48 on a photo).
/// Sans steps: body 17 · sub 15 · caption 13 · eyebrow 12.
enum HDFont {
    // MARK: Serif, regular

    /// 48 serif, capped at 64: her name on a full-bleed photo (profile hero).
    static var heroName: Font {
        Font.system(size: min(UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: 48), 64), weight: .regular, design: .serif)
    }
    /// 40 serif: tab-root titles ("Bookings."), greetings, "You're booked.", the mode-switch frame.
    static var display: Font { serif(40, relativeTo: .largeTitle) }
    /// 34 serif: step titles, "Kiara at yours.", detail headlines.
    static var title: Font { serif(34, relativeTo: .largeTitle) }
    /// 28 serif: sheet titles, the ConfirmSheet question, empty and error lines, day heads.
    static var titleSmall: Font { serif(28, relativeTo: .title1) }
    /// 26 serif: section heads ("Who's free today", "Near you").
    static var section: Font { serif(26, relativeTo: .title1) }
    /// 22 serif: names in rows.
    static var name: Font { serif(22, relativeTo: .title2) }
    /// 21 serif: the name in an ink bar (Book bar, Next up).
    static var nameBar: Font { serif(21, relativeTo: .title3) }
    /// 19 serif: names under photos.
    static var nameSmall: Font { serif(19, relativeTo: .title3) }
    /// 19 serif: bio, review pull quotes, record lines.
    static var quote: Font { serif(19, relativeTo: .body) }
    /// 16 serif: the word under a category photo.
    static var categoryWord: Font { serif(16, relativeTo: .callout) }
    /// 17 serif: a centred nav-bar title.
    static var navTitle: Font { serif(17, relativeTo: .headline) }
    /// 19 serif italic: one leaned-on line.
    static var serifItalic: Font { serif(19, relativeTo: .title3).italic() }
    /// 15 serif italic: a note in her words.
    static var italicSub: Font { serif(15, relativeTo: .subheadline).italic() }

    /// Deprecated alias. Same as `display` (40). Was 34 medium.
    static var hero: Font { display }
    /// Deprecated alias. 22 regular, same as `name`. Prefer `section` (26) for section heads.
    static var heading: Font { name }

    // MARK: Sans

    static let body       = Font.system(.body)
    /// Buttons and emphasis. 17 semibold.
    static let bodyStrong = Font.system(.body).weight(.semibold)
    static let sub        = Font.system(.subheadline)
    static let subStrong  = Font.system(.subheadline).weight(.semibold)
    /// 15 medium: text links, OptionBox labels, TextTabs.
    static let subMedium  = Font.system(.subheadline).weight(.medium)
    static let caption    = Font.system(.footnote)
    /// 12 medium. Use with `labelStyle()` / `eyebrowStyle()`, which add the caps and tracking.
    static let eyebrow    = Font.system(.caption).weight(.medium)
    /// Deprecated alias of `eyebrow` (was semibold).
    static let label      = Font.system(.caption).weight(.medium)

    // MARK: Money: SF, monospaced digits, never serif, never bold in a list

    /// 17 regular: a line item.
    static let price       = Font.system(.body).monospacedDigit()
    /// 17 semibold: a price that must stand out in a row (rare).
    static let priceStrong = Font.system(.body).weight(.semibold).monospacedDigit()
    /// 15 regular: "from $95" beside a name.
    static let priceSmall  = Font.system(.subheadline).monospacedDigit()
    /// 22 regular: a money fact ("Today $230").
    static let priceLarge  = Font.system(.title2).monospacedDigit()
    /// 28 regular: a receipt total, "To you".
    static var priceTotal: Font { sans(28, relativeTo: .title1).monospacedDigit() }
    /// 36 regular: the one big number on the ticket.
    static var priceDisplay: Font { sans(36, relativeTo: .largeTitle).monospacedDigit() }
    /// 56 light: Earnings' week total.
    static var priceHero: Font { sans(56, relativeTo: .largeTitle, weight: .light).monospacedDigit() }
    /// 56 light: a time as the hero of a block ("12:30" on Today's Next up, the biggest thing there).
    static var timeDisplay: Font { sans(56, relativeTo: .largeTitle, weight: .light).monospacedDigit() }
    /// Deprecated alias of `priceTotal`. Was serif.
    static var numeral: Font { priceTotal }

    // MARK: Builders, for the odd size the scale doesn't name

    /// New York at a design size that follows Dynamic Type. Regular unless there's a reason.
    static func serif(_ size: CGFloat, relativeTo style: UIFont.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        Font.system(size: UIFontMetrics(forTextStyle: style).scaledValue(for: size), weight: weight, design: .serif)
    }

    /// SF Pro at a design size that follows Dynamic Type.
    static func sans(_ size: CGFloat, relativeTo style: UIFont.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        Font.system(size: UIFontMetrics(forTextStyle: style).scaledValue(for: size), weight: weight, design: .default)
    }
}

extension View {
    /// Uppercase, tracked eyebrow for small section markers ("NEAR YOU", "2 OF 5"). 12 medium,
    /// tracking 1, inkSoft. The one eyebrow style; `homeEyebrow` and `profileEyebrow` fold into it.
    func labelStyle() -> some View {
        eyebrowStyle()
    }

    /// The eyebrow in any colour: pass `Palette.onInkSoft` on ink, `Palette.onPhoto` on a photo.
    func eyebrowStyle(color: Color = Palette.inkSoft) -> some View {
        self.font(HDFont.eyebrow)
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(color)
    }
}
