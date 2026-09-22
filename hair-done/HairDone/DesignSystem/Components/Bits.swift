import SwiftUI

/// Serif section heading with an optional trailing action. "Near you   See all"
struct SectionHeader: View {
    var title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(HDFont.heading).foregroundStyle(Palette.ink)
                if let subtitle { Text(subtitle).font(HDFont.sub).foregroundStyle(Palette.inkSoft) }
            }
            Spacer()
            if let actionTitle, let action {
                Button(action: { Haptics.light(); action() }) {
                    Text(actionTitle).font(HDFont.subStrong).foregroundStyle(Palette.lacquer)
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Empty state: a serif line, a soft sub-line, an optional action. Sits mid-screen.
struct EmptyState: View {
    var symbol: String = "sparkles"
    var title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Palette.inkFaint)
                .padding(.bottom, 4)
            Text(title).font(HDFont.heading).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
            if let message { Text(message).font(HDFont.sub).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center) }
            if let actionTitle, let action {
                Button(action: { Haptics.light(); action() }) {
                    Text(actionTitle).font(HDFont.subStrong).foregroundStyle(Palette.lacquer)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 36)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

/// Key-value row for receipts and breakdowns.
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

/// A row with a leading symbol, a title, an optional value, and a chevron. For settings lists.
struct NavRow: View {
    var symbol: String
    var title: String
    var value: String? = nil
    var tint: Color = Palette.ink
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.light(); action() }) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 28)
                Text(title).font(HDFont.body).foregroundStyle(tint)
                Spacer()
                if let value { Text(value).font(HDFont.sub).foregroundStyle(Palette.inkSoft) }
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.inkFaint)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Rounded text field with a label above it.
struct HDTextField: View {
    var label: String
    var placeholder: String = ""
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !label.isEmpty { Text(label).font(HDFont.subStrong).foregroundStyle(Palette.ink) }
            TextField(placeholder, text: $text, axis: axis)
                .font(HDFont.body)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.input, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
        }
    }
}

/// A hairline divider that respects the palette.
struct Hairline: View {
    var body: some View { Rectangle().fill(Palette.line).frame(height: 1) }
}

/// Header for sheets: grabber-friendly title row with a close button.
struct SheetHeader: View {
    var title: String
    var subtitle: String? = nil
    var onClose: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(HDFont.title).foregroundStyle(Palette.ink)
                if let subtitle { Text(subtitle).font(HDFont.sub).foregroundStyle(Palette.inkSoft) }
            }
            Spacer()
            if let onClose { IconButton(symbol: "xmark", label: "Close", action: onClose) }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, 20)
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

/// The lacquer check that draws itself. The one big moment in the booking flow.
struct LacquerCheck: View {
    var size: CGFloat = 96
    @State private var trim: CGFloat = 0
    @State private var ring: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().fill(Palette.lacquerSoft)
            Circle().trim(from: 0, to: ring).stroke(Palette.lacquer, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
            CheckShape().trim(from: 0, to: trim)
                .stroke(Palette.lacquer, style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round, lineJoin: .round))
                .padding(size * 0.28)
        }
        .frame(width: size, height: size)
        .onAppear {
            if reduceMotion { trim = 1; ring = 1; return }
            withAnimation(.easeOut(duration: 0.5)) { ring = 1 }
            withAnimation(.easeInOut(duration: 0.45).delay(0.25)) { trim = 1 }
        }
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

/// The brand mark: a lacquer drop. Draws with Path so it scales anywhere.
struct DropMark: View {
    var size: CGFloat = 28
    var color: Color = Palette.lacquer
    var body: some View {
        DropShape()
            .fill(color)
            .overlay(
                Ellipse().fill(Color.white.opacity(0.8))
                    .frame(width: size * 0.16, height: size * 0.24)
                    .rotationEffect(.degrees(18))
                    .offset(x: -size * 0.15, y: -size * 0.02)
            )
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct DropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let r = rect.width * 0.32
        let cy = rect.maxY - r - rect.height * 0.04
        let apex = CGPoint(x: cx, y: rect.minY + rect.height * 0.04)
        let d = cy - apex.y
        let th = acos(r / d)
        p.move(to: apex)
        let start = Angle(radians: -Double.pi / 2 + th)
        let end = Angle(radians: -Double.pi / 2 - th + 2 * Double.pi)
        p.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// The wordmark, three lines, lowercase serif.
struct Wordmark: View {
    var size: CGFloat = 34
    var body: some View {
        VStack(alignment: .leading, spacing: -2) {
            Text("hair done.")
            Text("nails done.")
            Text("everything ") + Text("done.").italic()
        }
        .font(.system(size: size, weight: .medium, design: .serif))
        .foregroundStyle(Palette.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hair done, nails done, everything done")
    }
}
