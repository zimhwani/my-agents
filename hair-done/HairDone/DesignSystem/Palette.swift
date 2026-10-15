import SwiftUI

/// Every colour in the app comes from here. See docs/build-brief.md §4 and docs/design/components.md.
/// Light and dark values are paired so a screen never has to think about scheme.
///
/// Contrast (WCAG 2.1, worked out with the sRGB luminance formula; re-run if a value changes):
/// - ink on paper 15.4:1 · inkSoft on paper 5.3:1 (dark 7.9:1)
/// - paper #FBF7F2 on lacquerFill #C8323A 4.96:1, light and dark (AA for body text)
/// - white on the old dark lacquer #E2504F was 3.8:1, which failed AA (audit M23). Filled
///   lacquer now stays #C8323A in dark; #E2504F is kept for dots and strokes only (4.9:1 on dark paper).
/// - onInk on inkGround 14.6:1 light, 16.9:1 dark (#0E0A09) · onInk at 55% on #241A16 5.3:1 ·
///   onInkSoft (62%) on dark inkGround 6.8:1
/// - Dark inkGround #0E0A09 sits *below* dark paper #171210 (1.06:1), so an ink block reads as a
///   deeper well, not a lit card; `inkEdge` (#3A302B, 1.5:1 on dark paper) gives it its edge.
/// - inkFaint on paper 3.1:1 light, 4.0:1 dark: enough for a glyph or hairline (3:1), not for text.
enum Palette {
    // MARK: Ground and type

    static let paper       = dyn(light: 0xF8F3EC, dark: 0x171210)
    /// White surface. Retired for new screens (luxe: paper and hairlines, not cards). Kept for sheets
    /// that still sit on it.
    static let card        = dyn(light: 0xFFFFFF, dark: 0x221B18)
    static let cardRaised  = dyn(light: 0xFFFFFF, dark: 0x2A2220)
    static let ink         = dyn(light: 0x241A16, dark: 0xF4ECE4)
    /// Secondary text. The lightest colour any text may use.
    static let inkSoft     = dyn(light: 0x6F625B, dark: 0xB5A79D)
    /// Hairlines, decorative glyphs (chevrons), disabled fills. **Never text**: 3.1:1 on paper
    /// passes for a glyph and fails for words. Use `inkSoft` for any text.
    static let inkFaint    = dyn(light: 0x948880, dark: 0x7D726B)
    static let line        = dyn(light: 0xE8DFD5, dark: 0x3A302B)
    /// The hairline between data rows (price lists, receipts, settings). Visible on paper, unlike `line`.
    static let lineStrong  = dyn(light: 0xDDD2C5, dark: 0x3A302B)

    // MARK: Lacquer: Pay, Request, the unread dot, the active-tab dot, the check. Nothing else.

    /// Dots, strokes and the drawn check. Brighter in dark so a 4pt dot still reads.
    static let lacquer     = dyn(light: 0xC8323A, dark: 0xE2504F)
    /// Filled lacquer surfaces (the Pay button). Fixed in both modes so its label passes AA.
    static let lacquerFill = Color(hex: 0xC8323A)
    static let lacquerDeep = dyn(light: 0xA3252C, dark: 0xC9403F)
    /// Small tinted areas only (the offline bar). Text on it is `ink`, never `inkSoft`.
    static let lacquerSoft = dyn(light: 0xF6DEDC, dark: 0x4A2626)
    /// Label on `lacquerFill`. Warm paper, not pure white (brand rule 8).
    static let onLacquer   = Color(hex: 0xFBF7F2)

    // MARK: Ink moments: the booking ticket, Next up, the Book bar, the pro tab bar

    /// The ink ground. #241A16 in light. In dark it's darker than dark paper (#0E0A09 on #171210),
    /// so an ink block is a deeper well rather than a lit card. Its edge in dark comes from
    /// `inkEdge`; `inkBlock()` adds it. Also the fill for selections, my bubble, toasts and undo bars,
    /// with `onInk` type (never `Palette.ink` as a fill: that's cream in dark).
    static let inkGround   = dyn(light: 0x241A16, dark: 0x0E0A09)
    /// A surface on the ink ground (a card on the ticket, a selected row). A step up from it.
    static let inkRaised   = dyn(light: 0x2E2521, dark: 0x241C18)
    /// The edge round an ink block or ink bar: the ink itself in light (no visible line), a
    /// lineStrong-weight hairline in dark, where the block is darker than the paper.
    static let inkEdge     = dyn(light: 0x241A16, dark: 0x3A302B)
    /// Paper type and glyphs on `inkGround`. Fixed: the ground is dark in both modes.
    static let onInk       = Color(hex: 0xF4ECE4)
    /// Secondary type on ink. 6.3:1 on #241A16.
    static let onInkSoft   = Color(hex: 0xF4ECE4).opacity(0.62)
    /// Hairlines on ink, and the shimmer on an ink block. A touch stronger on the darker dark ground.
    static let inkLine     = dyn(light: 0xF4ECE4, lightAlpha: 0.14, dark: 0xF4ECE4, darkAlpha: 0.16)
    /// Type set on a photo (the hero name). Fixed.
    static let onPhoto     = Color(hex: 0xFBF7F2)
    /// Behind a photo that hasn't loaded.
    static let photoGround = dyn(light: 0xCBBFB2, dark: 0x2E2622)

    // MARK: Status and stars

    static let honey       = dyn(light: 0xE9B96A, dark: 0xE9B96A)
    /// Status dots only. Not for text, money or tips.
    static let success     = dyn(light: 0x3E7A5A, dark: 0x6FBF8F)
    static let successSoft = dyn(light: 0xDDEBE2, dark: 0x213A2C)
    /// Status dots and warning rules only. As text it fails AA (3.4:1); set the words in ink with a warn dot.
    static let warn        = dyn(light: 0xB9741F, dark: 0xE6A44C)
    static let warnSoft    = dyn(light: 0xF6E7D0, dark: 0x3E2E17)

    /// Category tints. Retired from UI (benchmark §4): kept only for placeholder art and old call sites.
    static func tint(_ category: Category) -> Color {
        switch category {
        case .hair:   return dyn(light: 0xE3D6C8, dark: 0x3E332C)
        case .nails:  return dyn(light: 0xE6CDC5, dark: 0x43322F)
        case .makeup: return dyn(light: 0xDECDD5, dark: 0x3E3238)
        case .lashes: return dyn(light: 0xD5D1DC, dark: 0x34323C)
        case .brows:  return dyn(light: 0xD2D7CA, dark: 0x323830)
        case .theLot: return dyn(light: 0xE6DBC4, dark: 0x3F3A2C)
        }
    }

    /// A deeper companion to each tint, for ink on top of a tinted surface. Retired with `tint`.
    static func tintInk(_ category: Category) -> Color {
        switch category {
        case .hair:   return dyn(light: 0x6B4A33, dark: 0xE7CDB8)
        case .nails:  return dyn(light: 0x8C3A34, dark: 0xF0BDB6)
        case .makeup: return dyn(light: 0x6E3E5C, dark: 0xE6C4DA)
        case .lashes: return dyn(light: 0x46406B, dark: 0xD3CEEA)
        case .brows:  return dyn(light: 0x48583A, dark: 0xCFDCC0)
        case .theLot: return dyn(light: 0x7A5F1F, dark: 0xEBDBAE)
        }
    }

    // MARK: - Helpers

    static func dyn(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    static func dyn(light: UInt32, lightAlpha: CGFloat, dark: UInt32, darkAlpha: CGFloat) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark, alpha: darkAlpha) : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32) { self.init(UIColor(hex: hex)) }
}
