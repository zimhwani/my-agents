import SwiftUI

// Buttons. Squared (6pt), SF 17 semibold labels, at least 52pt tall (44 when `compact`).
// Ink is the default action colour. Lacquer is for money only: `Pay $180`, `Request · $95`.

/// The lacquer button. **Money only**: `Pay $X`, `Request · $X`. For anything else use `InkButton`.
/// Fill is `lacquerFill` in both modes so the paper label passes AA (4.96:1).
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
            ButtonLabel(title: title, symbol: symbol, isLoading: isLoading, tint: isEnabled ? Palette.onLacquer : Palette.inkSoft)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(isEnabled ? Palette.lacquerFill : Palette.line, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(PressLift())
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(title)
    }
}

/// The default action: ink fill, paper label. Save, Next, Accept, Message Kiara, Cancel it.
/// `tone: .onInk` inverts it for ink grounds (paper fill, ink label), like the profile's Book.
struct InkButton: View {
    enum Tone { case ink, onInk }

    var title: String
    var symbol: String? = nil
    var isLoading = false
    var isEnabled = true
    var tone: Tone = .ink
    /// 44pt tall instead of 52, for two buttons side by side in a row.
    var compact = false
    var action: () -> Void

    var body: some View {
        Button {
            guard isEnabled, !isLoading else { return }
            Haptics.medium()
            action()
        } label: {
            ButtonLabel(title: title, symbol: symbol, isLoading: isLoading, tint: labelColor)
                .frame(maxWidth: .infinity, minHeight: compact ? 44 : 52)
                .background(fill, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(PressLift())
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(title)
    }

    private var fill: Color {
        guard isEnabled else { return tone == .ink ? Palette.line : Palette.onInk.opacity(0.18) }
        return tone == .ink ? Palette.ink : Palette.onInk
    }

    private var labelColor: Color {
        guard isEnabled else { return tone == .ink ? Palette.inkSoft : Palette.onInkSoft }
        return tone == .ink ? Palette.paper : Color(hex: 0x241A16)
    }
}

/// The quiet sibling: 1pt ink border, ink label, no fill. Reschedule, Decline, Add a service.
/// `tone: .onInk` for ink grounds (paper border and label).
struct OutlineButton: View {
    enum Tone { case paper, onInk }

    var title: String
    var symbol: String? = nil
    var isLoading = false
    var isEnabled = true
    var tone: Tone = .paper
    var compact = false
    var action: () -> Void

    var body: some View {
        Button {
            guard isEnabled, !isLoading else { return }
            Haptics.light()
            action()
        } label: {
            ButtonLabel(title: title, symbol: symbol, isLoading: isLoading, tint: color.opacity(isEnabled ? 1 : 0.45))
                .frame(maxWidth: .infinity, minHeight: compact ? 44 : 52)
                .contentShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                        .strokeBorder(color.opacity(isEnabled ? 1 : 0.3), lineWidth: 1)
                )
        }
        .buttonStyle(PressLift())
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(title)
    }

    private var color: Color { tone == .paper ? Palette.ink : Palette.onInk }
}

/// Text only, 44pt tall: "Not now", "Skip for now", "Cancel booking", "Book again".
/// inkSoft by default; pass `tint: Palette.ink` for a text link that is the action. Never lacquer.
struct TertiaryButton: View {
    var title: String
    var tint: Color = Palette.inkSoft
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.light(); action() }) {
            Text(title)
                .font(HDFont.subMedium)
                .foregroundStyle(tint)
                .frame(minHeight: 44)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A bare glyph with a 44pt hit area: back, close, share, heart, week arrows. No disc, no ring.
/// Outline symbols only; `filled` is ignored (kept so old call sites compile).
struct IconButton: View {
    var symbol: String
    var label: String
    var filled = false
    var tint: Color = Palette.ink
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.light(); action() }) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
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

/// A sticky bottom bar on paper: leading summary, an action on the right.
/// The action is an `InkButton`; pass `isMoney: true` only when the title is `Pay $X` or `Request · $X`.
struct StickyBar<Leading: View>: View {
    var title: String
    var isLoading = false
    var isEnabled = true
    var isMoney = false
    var action: () -> Void
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        HStack(spacing: 16) {
            leading()
            Group {
                if isMoney {
                    PrimaryButton(title: title, isLoading: isLoading, isEnabled: isEnabled, action: action)
                } else {
                    InkButton(title: title, isLoading: isLoading, isEnabled: isEnabled, action: action)
                }
            }
            .frame(maxWidth: 220)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Palette.paper.opacity(0.94))
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
    }
}

/// The shared label inside the filled and outline buttons.
private struct ButtonLabel: View {
    var title: String
    var symbol: String?
    var isLoading: Bool
    var tint: Color

    var body: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView().tint(tint)
            } else {
                if let symbol { Image(systemName: symbol).font(.system(size: 15, weight: .regular)) }
                Text(title).multilineTextAlignment(.center)
            }
        }
        .font(HDFont.bodyStrong)
        .foregroundStyle(tint)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview("Buttons") {
    VStack(spacing: 12) {
        PrimaryButton(title: "Pay $113") {}
        InkButton(title: "Message Kiara") {}
        HStack(spacing: 12) {
            InkButton(title: "Accept", compact: true) {}
            OutlineButton(title: "Decline", compact: true) {}
        }
        OutlineButton(title: "Reschedule") {}
        InkButton(title: "Save", isEnabled: false) {}
        TertiaryButton(title: "Cancel booking") {}
        HStack { IconButton(symbol: "chevron.left", label: "Back") {}; Spacer(); IconButton(symbol: "xmark", label: "Close") {} }
        VStack(spacing: 12) {
            InkButton(title: "Book", tone: .onInk) {}
            OutlineButton(title: "Change", tone: .onInk) {}
        }
        .padding(16)
        .background(Palette.inkGround)
    }
    .padding(20)
    .paperBackground()
}
