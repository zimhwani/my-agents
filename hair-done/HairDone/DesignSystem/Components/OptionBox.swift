import SwiftUI

/// Something she picks. Two shapes, one rule: hairlines and ink, never a lacquer ring.
///
/// - `.box` (default): 6pt corners, 1pt `line` border, at least 40pt tall. Selected = `inkGround`
///   fill and `onInk` text (with an ink edge, cream in dark) for a short label, or an ink border and an ink check for rich content.
///   Tips, km presets, time slots, address labels, quick replies, payment methods.
/// - `.row`: a hairline row with no box; selected = an ink check on the right. Decline reasons,
///   services as a price list, addresses.
///
///     OptionBox(title: "$10", isSelected: tip == 10) { tip = 10 }
///     OptionBox(isSelected: picked, style: .row) { pick() } content: { Text("Home") }
///
/// Drop-in for the old `SelectableCard(isSelected:action:content:)`: same argument order.
struct OptionBox<Content: View>: View {
    typealias Style = OptionBoxStyle

    var isSelected: Bool
    var style: Style
    var action: () -> Void
    private let content: Content
    private let isLabel: Bool

    /// Rich content (a service, an address). Selected shows an ink check.
    init(isSelected: Bool, style: Style = .box, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.style = style
        self.action = action
        self.content = content()
        self.isLabel = false
    }

    var body: some View {
        Button(action: { Haptics.selection(); action() }) {
            Group {
                if isLabel {
                    content
                        .font(HDFont.subMedium)
                        .foregroundStyle(isSelected ? Palette.onInk : Palette.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(minHeight: 40)
                        // The ink ground, not `Palette.ink` (cream in dark). The ink border is
                        // invisible on it in light and a cream edge in dark, so the pick still stands out.
                        .background(isSelected ? Palette.inkGround : Color.clear, in: shape)
                        .overlay(shape.strokeBorder(isSelected ? Palette.ink : Palette.line, lineWidth: 1))
                        .contentShape(shape)
                } else {
                    HStack(spacing: Space.m) {
                        content
                        Spacer(minLength: 0)
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Palette.ink)
                            .opacity(isSelected ? 1 : 0)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .modifier(OptionChrome(style: style, isSelected: isSelected))
                }
            }
        }
        .buttonStyle(PressLift(scale: 0.985))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Radius.card, style: .continuous) }
}

extension OptionBox where Content == Text {
    /// A short label ("$10", "15 km", "6:30 pm", "On my way"). Selected = ink ground, paper text.
    init(title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.isSelected = isSelected
        self.style = .box
        self.action = action
        self.content = Text(title)
        self.isLabel = true
    }
}

/// `.box` or `.row`. See `OptionBox`.
enum OptionBoxStyle { case box, row }

private struct OptionChrome: ViewModifier {
    var style: OptionBoxStyle
    var isSelected: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        switch style {
        case .box:
            content
                .padding(.horizontal, Space.l)
                .padding(.vertical, Space.m)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(isSelected ? Palette.ink : Palette.line, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        case .row:
            content
                .padding(.vertical, Space.m)
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
                .contentShape(Rectangle())
        }
    }
}

private struct OptionBoxPreview: View {
    @State private var tip = 10
    @State private var reason = "Too far"
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 8) {
                ForEach([0, 5, 10, 20], id: \.self) { t in
                    OptionBox(title: t == 0 ? "No tip" : "$\(t)", isSelected: tip == t) { tip = t }
                }
            }
            OptionBox(isSelected: true, action: {}) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Home").font(HDFont.body).foregroundStyle(Palette.ink)
                    Text("14 Rae St, Fitzroy North").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                }
            }
            VStack(spacing: 0) {
                ForEach(["Too far", "Booked out", "Something else"], id: \.self) { r in
                    OptionBox(isSelected: reason == r, style: .row, action: { reason = r }) {
                        Text(r).font(HDFont.body).foregroundStyle(Palette.ink)
                    }
                }
            }
        }
        .padding(20)
        .paperBackground()
    }
}

#Preview("OptionBox") { OptionBoxPreview() }
