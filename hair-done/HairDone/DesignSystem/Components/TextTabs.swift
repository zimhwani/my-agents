import SwiftUI

/// Underlined text tabs: the List | Map pattern from Home. Replaces pill segment chips and the
/// system segmented Picker. SF 15 (or serif 17 for Work's category filters), inkSoft when off,
/// ink with a 1pt ink underline when on. Sits on the title row, aligned to its baseline.
///
///     TextTabs(selection: $segment, options: Segment.allCases) { $0.rawValue }
struct TextTabs<Value: Hashable>: View {
    enum Style { case sans, serif }

    @Binding var selection: Value
    var options: [Value]
    var style: Style = .sans
    var spacing: CGFloat = 18
    var label: (Value) -> String

    @Namespace private var underline

    init(selection: Binding<Value>, options: [Value], style: Style = .sans, spacing: CGFloat = 18, label: @escaping (Value) -> String) {
        self._selection = selection
        self.options = options
        self.style = style
        self.spacing = spacing
        self.label = label
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: spacing) {
            ForEach(options, id: \.self) { option in
                let isOn = option == selection
                Button {
                    guard !isOn else { return }
                    Haptics.selection()
                    withAnimation(Motion.spring) { selection = option }
                } label: {
                    Text(label(option))
                        .font(style == .sans ? HDFont.subMedium : HDFont.serif(17, relativeTo: .headline))
                        .foregroundStyle(isOn ? Palette.ink : Palette.inkSoft)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.bottom, 4)
                        .overlay(alignment: .bottom) {
                            if isOn {
                                Rectangle().fill(Palette.ink).frame(height: 1)
                                    .matchedGeometryEffect(id: "underline", in: underline)
                            }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

private struct TextTabsPreview: View {
    @State private var tab = "Upcoming"
    @State private var filter = "All"
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .firstTextBaseline) {
                Text("Bookings.").font(HDFont.display)
                Spacer()
                TextTabs(selection: $tab, options: ["Upcoming", "Past"]) { $0 }
            }
            TextTabs(selection: $filter, options: ["All", "Nails", "Hair", "Lashes"], style: .serif) { $0 }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperBackground()
    }
}

#Preview("TextTabs") { TextTabsPreview() }
