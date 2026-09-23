import SwiftUI

/// The type scale. Display is the system serif (New York); body is SF Pro.
/// Every size here scales with Dynamic Type: text-style based, or through UIFontMetrics.
enum HDFont {
    /// 42 regular serif. The Home greeting. One per app.
    static var display: Font {
        Font.system(size: UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: 42), weight: .regular, design: .serif)
    }
    static let hero    = Font.system(.largeTitle, design: .serif).weight(.medium)
    static let title   = Font.system(.title, design: .serif).weight(.medium)
    static let heading = Font.system(.title3, design: .serif).weight(.medium)
    /// 20 medium serif. Pro names on tiles and cards.
    static let name    = Font.system(.title3, design: .serif).weight(.medium)
    static let body    = Font.system(.body)
    static let bodyStrong = Font.system(.body).weight(.semibold)
    static let sub     = Font.system(.subheadline)
    static let subStrong = Font.system(.subheadline).weight(.semibold)
    static let caption = Font.system(.footnote)
    static let label   = Font.system(.caption).weight(.semibold)
    static let eyebrow = Font.system(.caption).weight(.medium)
    static let price   = Font.system(.body).weight(.semibold).monospacedDigit()
    static let priceLarge = Font.system(.title2, design: .serif).weight(.medium).monospacedDigit()
    /// 28 regular serif, monospaced digits. Totals and the rating number on a profile.
    static var numeral: Font {
        Font.system(size: UIFontMetrics(forTextStyle: .title1).scaledValue(for: 28), weight: .regular, design: .serif).monospacedDigit()
    }
    static let serifItalic = Font.system(.title3, design: .serif).italic()
    static let italicSub = Font.system(.subheadline, design: .serif).italic()
}

extension View {
    /// Uppercase, tracked label for small section markers. Use sparingly.
    func labelStyle() -> some View {
        self.font(HDFont.label)
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(Palette.inkSoft)
    }
}
