import SwiftUI

/// Every colour in the app comes from here. See docs/build-brief.md §4 and docs/design/luxe-pass.md.
/// Light and dark values are paired so a screen never has to think about scheme.
enum Palette {
    static let paper       = dyn(light: 0xF8F3EC, dark: 0x171210)
    static let card        = dyn(light: 0xFFFFFF, dark: 0x221B18)
    static let cardRaised  = dyn(light: 0xFFFFFF, dark: 0x2A2220)
    static let ink         = dyn(light: 0x241A16, dark: 0xF4ECE4)
    static let inkSoft     = dyn(light: 0x6F625B, dark: 0xB5A79D)
    static let inkFaint    = dyn(light: 0xA1968E, dark: 0x7D726B)
    /// Hairlines carry the structure now that cards don't, so this is a shade darker than the brief's.
    static let line        = dyn(light: 0xE2D8CC, dark: 0x3A302B)
    static let lacquer     = dyn(light: 0xC8323A, dark: 0xE2504F)
    static let lacquerDeep = dyn(light: 0xA3252C, dark: 0xC9403F)
    static let lacquerSoft = dyn(light: 0xF1DBD7, dark: 0x4A2626)
    static let honey       = dyn(light: 0xE9B96A, dark: 0xE9B96A)
    static let success     = dyn(light: 0x3E7A5A, dark: 0x6FBF8F)
    static let successSoft = dyn(light: 0xE0E9E1, dark: 0x213A2C)
    static let warn        = dyn(light: 0xB9741F, dark: 0xE6A44C)
    static let warnSoft    = dyn(light: 0xF0E5D2, dark: 0x3E2E17)
    static let onLacquer   = Color.white

    /// Category tints used on Pro-mode chips and placeholder art. Stone, rose-brown, mauve,
    /// grey lilac, sage, sand: desaturated and a touch darker than the brief's pastels.
    static func tint(_ category: Category) -> Color {
        switch category {
        case .hair:   return dyn(light: 0xDCCFC2, dark: 0x3E332C)
        case .nails:  return dyn(light: 0xDDC4BC, dark: 0x43322F)
        case .makeup: return dyn(light: 0xD6C7CE, dark: 0x3E3238)
        case .lashes: return dyn(light: 0xCFCBD6, dark: 0x34323C)
        case .brows:  return dyn(light: 0xCBD0C3, dark: 0x323830)
        case .theLot: return dyn(light: 0xDED3BC, dark: 0x3F3A2C)
        }
    }

    /// A deeper companion to each tint, for ink on top of a tinted surface.
    static func tintInk(_ category: Category) -> Color {
        switch category {
        case .hair:   return dyn(light: 0x5A4638, dark: 0xE7CDB8)
        case .nails:  return dyn(light: 0x6E4640, dark: 0xF0BDB6)
        case .makeup: return dyn(light: 0x5C4452, dark: 0xE6C4DA)
        case .lashes: return dyn(light: 0x474258, dark: 0xD3CEEA)
        case .brows:  return dyn(light: 0x44503C, dark: 0xCFDCC0)
        case .theLot: return dyn(light: 0x66562E, dark: 0xEBDBAE)
        }
    }

    // MARK: - Helpers

    static func dyn(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
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
