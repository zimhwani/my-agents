import SwiftUI

/// Spacing and shape tokens. Unit is 4.
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let gutter: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let section: CGFloat = 36
}

enum Radius {
    static let card: CGFloat = 18
    static let tile: CGFloat = 14
    static let input: CGFloat = 14
    static let chip: CGFloat = 999
    /// Buttons are squared, not pills: the luxe direction (docs/design/luxe-benchmark.md).
    static let button: CGFloat = 6
}

enum Motion {
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let springSlow = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let gentle = Animation.easeInOut(duration: 0.25)
}

/// A card: white on paper in light, slightly lifted surface in dark, hairline edge.
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
    func floating() -> some View { modifier(FloatingShadow()) }
    func screenGutter() -> some View { padding(.horizontal, Space.gutter) }
    func paperBackground() -> some View { background(Palette.paper.ignoresSafeArea()) }

    /// Applies a modifier conditionally without breaking the view chain.
    @ViewBuilder
    func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}
