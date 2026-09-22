import SwiftUI

/// The six things you can get done. Order matters: it's the order on the home screen.
enum Category: String, CaseIterable, Codable, Identifiable, Hashable {
    case hair, nails, makeup, lashes, brows, theLot

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hair: return "Hair"
        case .nails: return "Nails"
        case .makeup: return "Makeup"
        case .lashes: return "Lashes"
        case .brows: return "Brows"
        case .theLot: return "The lot"
        }
    }

    /// What a pro who does this is called.
    var specialtyTitle: String {
        switch self {
        case .hair: return "Hair stylist"
        case .nails: return "Nail tech"
        case .makeup: return "Makeup artist"
        case .lashes: return "Lash tech"
        case .brows: return "Brow artist"
        case .theLot: return "Does the lot"
        }
    }

    var symbol: String {
        switch self {
        case .hair: return "scissors"
        case .nails: return "hand.raised.fingers.spread"
        case .makeup: return "paintbrush.pointed"
        case .lashes: return "eye"
        case .brows: return "eyebrow"
        case .theLot: return "sparkles"
        }
    }

    var tint: Color { Palette.tint(self) }
    var tintInk: Color { Palette.tintInk(self) }

    /// A short, human line under the category on the home screen.
    var blurb: String {
        switch self {
        case .hair: return "Blow-dries, braids, colour, cuts"
        case .nails: return "Gel, acrylics, BIAB, a good file and paint"
        case .makeup: return "Events, weddings, a Tuesday"
        case .lashes: return "Classic, hybrid, volume, lifts"
        case .brows: return "Lamination, tint, shape, henna"
        case .theLot: return "Hair and makeup, or all three, one visit"
        }
    }
}
