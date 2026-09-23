import SwiftUI

/// The type scale. Display is the system serif (New York); body is SF Pro.
/// Every size here scales with Dynamic Type: the text-style ones natively, the fixed-point
/// ones through `UIFontMetrics`, which is why those are computed rather than stored.
/// The scale and where each style goes: docs/design/luxe-pass.md §2.
enum HDFont {
    // MARK: Serif display

    /// 44 regular. The Home greeting. One per app.
    static var display: Font { serif(44, .regular, relativeTo: .largeTitle) }
    /// 38 medium. Screen titles and the pro's name on her profile.
    static var hero: Font { serif(38, .medium, relativeTo: .largeTitle) }
    /// 28 medium. Sheet titles.
    static let title   = Font.system(.title, design: .serif).weight(.medium)
    /// 24 medium. Section headers.
    static var heading: Font { serif(24, .medium, relativeTo: .title2) }
    /// 20 medium. Pro names in lists and tiles, the category words on Home.
    static let name    = Font.system(.title3, design: .serif).weight(.medium)
    /// 17 regular serif. Review quotes.
    static let serifBody = Font.system(.body, design: .serif)
    /// 20 italic. Her one-line headline, photo captions in the viewer.
    static let serifItalic = Font.system(.title3, design: .serif).italic()
    /// 15 italic. Section sub-lines.
    static let italicSub = Font.system(.subheadline, design: .serif).italic()

    // MARK: Numbers

    /// 28 regular serif, monospaced digits. Totals and the rating on a profile. Never bold.
    static var numeral: Font { serif(28, .regular, relativeTo: .title1).monospacedDigit() }
    /// 17 regular, monospaced digits. Prices in rows.
    static let price   = Font.system(.body).monospacedDigit()
    static var priceLarge: Font { numeral }

    // MARK: Sans

    static let body    = Font.system(.body)
    static let bodyStrong = Font.system(.body).weight(.semibold)
    static let sub     = Font.system(.subheadline)
    static let subStrong = Font.system(.subheadline).weight(.semibold)
    static let caption = Font.system(.footnote)
    /// 12 medium. Always through `labelStyle()` so it's uppercase and tracked.
    static let label   = Font.system(.caption).weight(.medium)
    static let eyebrow = Font.system(.caption).weight(.medium)

    private static func serif(_ size: CGFloat, _ weight: Font.Weight, relativeTo style: UIFont.TextStyle) -> Font {
        Font.system(size: UIFontMetrics(forTextStyle: style).scaledValue(for: size), weight: weight, design: .serif)
    }
}

extension View {
    /// Uppercase, tracked eyebrow for section markers and status. Use sparingly.
    func labelStyle() -> some View {
        self.font(HDFont.label)
            .textCase(.uppercase)
            .tracking(1.5)
            .foregroundStyle(Palette.inkSoft)
    }
}
