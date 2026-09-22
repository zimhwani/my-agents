import SwiftUI

/// The type scale. Display is the system serif (New York); body is SF Pro.
/// Every size here scales with Dynamic Type because it's built on text styles.
enum HDFont {
    static let hero    = Font.system(.largeTitle, design: .serif).weight(.medium)
    static let title   = Font.system(.title, design: .serif).weight(.medium)
    static let heading = Font.system(.title3, design: .serif).weight(.medium)
    static let body    = Font.system(.body)
    static let bodyStrong = Font.system(.body).weight(.semibold)
    static let sub     = Font.system(.subheadline)
    static let subStrong = Font.system(.subheadline).weight(.semibold)
    static let caption = Font.system(.footnote)
    static let label   = Font.system(.caption).weight(.semibold)
    static let price   = Font.system(.body).weight(.semibold).monospacedDigit()
    static let priceLarge = Font.system(.title2, design: .serif).weight(.medium).monospacedDigit()
    static let serifItalic = Font.system(.title3, design: .serif).italic()
}

extension View {
    /// Uppercase, tracked label for small section markers. Use sparingly.
    func labelStyle() -> some View {
        self.font(HDFont.label)
            .textCase(.uppercase)
            .tracking(1.0)
            .foregroundStyle(Palette.inkSoft)
    }
}
