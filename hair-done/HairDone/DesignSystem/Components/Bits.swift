import SwiftUI

/// Serif 26 section heading with an optional ink text action on its baseline. "Near you   See all"
struct SectionHeader: View {
    var title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(HDFont.section).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle { Text(subtitle).font(HDFont.sub).foregroundStyle(Palette.inkSoft) }
            }
            Spacer()
            if let actionTitle, let action {
                Button(action: { Haptics.light(); action() }) {
                    Text(actionTitle).font(HDFont.subMedium).foregroundStyle(Palette.ink)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Key-value row for receipts and breakdowns. Label SF 17, price SF monospaced, never serif.
/// `emphasis` is the total: semibold label, 22pt price.
struct PriceRow: View {
    var label: String
    var cents: Int
    var emphasis = false
    var note: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(emphasis ? HDFont.bodyStrong : HDFont.body).foregroundStyle(Palette.ink)
                if let note { Text(note).font(HDFont.caption).foregroundStyle(Palette.inkSoft) }
            }
            Spacer()
            Text(Money.format(cents)).font(emphasis ? HDFont.priceLarge : HDFont.price).foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A hairline divider. Default is the quiet 1pt `line` (inside old blocks); `strong: true` is the
/// 0.5pt `lineStrong` rule between data rows on paper, as on the profile's price list.
struct Hairline: View {
    var strong = false
    var body: some View {
        Rectangle().fill(strong ? Palette.lineStrong : Palette.line).frame(height: strong ? 0.5 : 1)
    }
}

/// Header for sheets: serif 28 title, optional inkSoft sub-line, and a bare `xmark` glyph (44pt hit
/// area, no disc). Give every sheet `.presentationBackground(Palette.paper)`.
struct SheetHeader: View {
    var title: String
    var subtitle: String? = nil
    var onClose: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: Space.s) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(HDFont.titleSmall).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 6)
            Spacer(minLength: 0)
            if let onClose {
                IconButton(symbol: "xmark", label: "Close", action: onClose)
                    .padding(.trailing, -12)
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}

/// Three soft dots for "she's typing" or short waits.
struct LoadingDots: View {
    @State private var on = false
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(Palette.inkFaint).frame(width: 6, height: 6)
                    .scaleEffect(on ? 1 : 0.6)
                    .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.15), value: on)
            }
        }
        .onAppear { on = true }
        .accessibilityLabel("Loading")
    }
}

/// The lacquer check that draws itself: a bare stroke, no disc, no ring (as on You're booked,
/// mockup 05). Used on You're booked, the rate sheet and the end of pro setup.
struct LacquerCheck: View {
    var size: CGFloat = 56
    @State private var trim: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CheckShape().trim(from: 0, to: trim)
            .stroke(Palette.lacquer, style: StrokeStyle(lineWidth: max(2, size * 0.05), lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size * 0.72)
            .onAppear {
                if reduceMotion { trim = 1; return }
                withAnimation(.easeInOut(duration: 0.5).delay(0.15)) { trim = 1 }
            }
            .accessibilityElement()
            .accessibilityLabel("Done")
    }
}

struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY - rect.height * 0.05))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.1))
        return p
    }
}

/// The mark, set in a line: "hd. nd." in serif italic, each full stop in lacquer.
/// Used in the Home bar and on the welcome screen. The dots stay lacquer on any ground.
struct MonogramMark: View {
    var size: CGFloat = 22
    var color: Color = Palette.ink
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text("hd").italic()
            Text(".").foregroundStyle(Palette.lacquer)
            Text(" nd").italic()
            Text(".").foregroundStyle(Palette.lacquer)
        }
        .font(.system(size: size, weight: .medium, design: .serif))
        .foregroundStyle(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hair done")
    }
}
