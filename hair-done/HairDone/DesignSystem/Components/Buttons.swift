import SwiftUI

/// The one red button. Full pill, 52pt, lifts slightly on press.
struct PrimaryButton: View {
    var title: String
    var symbol: String? = nil
    var isLoading = false
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button {
            guard isEnabled, !isLoading else { return }
            Haptics.medium()
            action()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(Palette.onLacquer)
                } else {
                    if let symbol { Image(systemName: symbol) }
                    Text(title)
                }
            }
            .font(HDFont.bodyStrong)
            .foregroundStyle(Palette.onLacquer)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isEnabled ? Palette.lacquer : Palette.inkFaint, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(PressLift())
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(title)
    }
}

/// Quiet sibling: ink on card with a hairline.
struct SecondaryButton: View {
    var title: String
    var symbol: String? = nil
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(HDFont.bodyStrong)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.button, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
        }
        .buttonStyle(PressLift())
    }
}

/// Text-only, for "Not now", "Skip", "Cancel booking".
struct TertiaryButton: View {
    var title: String
    var tint: Color = Palette.inkSoft
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.light(); action() }) {
            Text(title)
                .font(HDFont.subStrong)
                .foregroundStyle(tint)
                .frame(minHeight: 44)
                .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }
}

/// Small round icon button (back, close, heart, share).
struct IconButton: View {
    var symbol: String
    var label: String
    var filled = false
    var tint: Color = Palette.ink
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.light(); action() }) {
            Image(systemName: filled ? symbol + ".fill" : symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(Palette.card, in: Circle())
                .overlay(Circle().strokeBorder(Palette.line, lineWidth: 1))
        }
        .buttonStyle(PressLift(scale: 0.92))
        .accessibilityLabel(label)
    }
}

/// Scales down a touch on press. Used by every button and card.
struct PressLift: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A sticky bottom bar with a primary action, used on the pro profile and booking review.
struct StickyBar<Leading: View>: View {
    var title: String
    var isLoading = false
    var isEnabled = true
    var action: () -> Void
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        HStack(spacing: 16) {
            leading()
            PrimaryButton(title: title, isLoading: isLoading, isEnabled: isEnabled, action: action)
                .frame(maxWidth: 220)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Palette.paper.opacity(0.94))
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
    }
}
