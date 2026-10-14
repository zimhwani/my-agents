import SwiftUI

/// Spacing and shape tokens. Unit is 4.
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    /// Screen gutter. Every left edge on a paper screen lines up on it.
    static let gutter: CGFloat = 20
    static let cardPadding: CGFloat = 16
    /// Gap between sections. 32, as in the brief.
    static let section: CGFloat = 32
}

/// Squared, not round. Blocks 6, photos 2, no pills anywhere.
enum Radius {
    /// Blocks: buttons, option boxes, ink blocks, the toast, sheets' inner boxes.
    static let card: CGFloat = 6
    /// Buttons. Squared, not pills (docs/design/luxe-benchmark.md §4).
    static let button: CGFloat = 6
    /// Photos, and photo-shaped placeholders and skeletons.
    static let photo: CGFloat = 2
    /// Deprecated alias of `photo`. Was 14.
    static let tile: CGFloat = 2
    /// Deprecated. Inputs are underline fields now (`HDTextField`); a boxed field that remains gets 6.
    static let input: CGFloat = 6
    /// Deprecated. There are no capsule chips; an `OptionBox` is 6.
    static let chip: CGFloat = 6
}

enum Motion {
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let springSlow = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let gentle = Animation.easeInOut(duration: 0.25)
}

/// A block on paper: white in light, a lifted surface in dark, a hairline edge, 6pt corners.
/// The luxe screens avoid it: prefer hairline rows (`HairlineRow`) straight on paper.
struct CardBackground: ViewModifier {
    var padding: CGFloat = Space.cardPadding
    var radius: CGFloat = Radius.card
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Palette.line, lineWidth: 1)
            )
    }
}

/// An ink block on paper (Next up, the job hero, the Pro mode row): `inkGround` with a 0.5pt
/// paper hairline so it keeps an edge on dark paper.
struct InkBlock: ViewModifier {
    var padding: CGFloat = Space.cardPadding
    var radius: CGFloat = Radius.card
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .foregroundStyle(Palette.onInk)
            .background(Palette.inkGround, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Palette.onInk.opacity(0.10), lineWidth: 0.5)
            )
    }
}

/// One soft shadow, only for floating things (sticky bars, the Book button).
struct FloatingShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 8)
    }
}

extension View {
    func card(padding: CGFloat = Space.cardPadding, radius: CGFloat = Radius.card) -> some View {
        modifier(CardBackground(padding: padding, radius: radius))
    }
    /// See `InkBlock`.
    func inkBlock(padding: CGFloat = Space.cardPadding, radius: CGFloat = Radius.card) -> some View {
        modifier(InkBlock(padding: padding, radius: radius))
    }
    func floating() -> some View { modifier(FloatingShadow()) }
    func screenGutter() -> some View { padding(.horizontal, Space.gutter) }
    func paperBackground() -> some View { background(Palette.paper.ignoresSafeArea()) }

    /// Clips to the photo radius (2pt).
    func photoShape() -> some View {
        clipShape(RoundedRectangle(cornerRadius: Radius.photo, style: .continuous))
    }

    /// Applies a modifier conditionally without breaking the view chain.
    @ViewBuilder
    func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}
