import SwiftUI

/// Spacing and shape tokens. Unit is 4. Values: docs/design/luxe-pass.md §2.
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 40
    static let gutter: CGFloat = 24
    static let cardPadding: CGFloat = 20
    static let section: CGFloat = 44
}

enum Radius {
    static let card: CGFloat = 12
    static let tile: CGFloat = 6
    static let input: CGFloat = 10
    static let chip: CGFloat = 8
}

enum Motion {
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let springSlow = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let gentle = Animation.easeInOut(duration: 0.25)
    static let reveal = Animation.easeOut(duration: 0.55)
}

/// A card: a hairline on paper. No fill, no shadow. Use it where content needs a boundary to read
/// as one unit (a receipt, a settings group, a form), never to separate list items.
struct CardBackground: ViewModifier {
    var padding: CGFloat = Space.cardPadding
    var radius: CGFloat = Radius.card
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
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

/// The one reveal: content rises 10pt and fades in once, on first appear. Stagger sections with `delay`.
/// Under Reduce Motion it simply appears.
struct RevealOnAppear: ViewModifier {
    var delay: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 10)
            .onAppear {
                guard !shown else { return }
                if reduceMotion { shown = true; return }
                withAnimation(Motion.reveal.delay(delay)) { shown = true }
            }
    }
}

extension View {
    func card(padding: CGFloat = Space.cardPadding, radius: CGFloat = Radius.card) -> some View {
        modifier(CardBackground(padding: padding, radius: radius))
    }
    func floating() -> some View { modifier(FloatingShadow()) }
    func reveal(delay: Double = 0) -> some View { modifier(RevealOnAppear(delay: delay)) }
    func screenGutter() -> some View { padding(.horizontal, Space.gutter) }
    func paperBackground() -> some View { background(Palette.paper.ignoresSafeArea()) }

    /// Applies a modifier conditionally without breaking the view chain.
    @ViewBuilder
    func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}
