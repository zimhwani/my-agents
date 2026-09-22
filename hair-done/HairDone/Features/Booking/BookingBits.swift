import SwiftUI
import CoreLocation

// Small shared pieces for the booking flow, the reschedule sheet and the two editors.
// Nothing here is used outside Features/Booking.

/// Six thin segments across the top of the flow. Filled up to and including the current step.
struct FlowProgress: View {
    var current: Int
    var total: Int

    var body: some View {
        HStack(spacing: Space.xs) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? Palette.lacquer : Palette.line)
                    .frame(height: 3)
            }
        }
        .animation(Motion.spring, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(total)")
    }
}

/// A card you can pick: hairline normally, lacquer ring and a filled check when chosen.
struct SelectableCard<Content: View>: View {
    var isSelected: Bool
    var action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: { Haptics.light(); action() }) {
            HStack(spacing: Space.m) {
                content()
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(isSelected ? Palette.lacquer : Palette.inkFaint)
                    .accessibilityHidden(true)
            }
            .padding(Space.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(isSelected ? Palette.lacquer : Palette.line, lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(PressLift(scale: 0.985))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A quiet one-liner under a control: "She's off Sundays." or "Too close to another job."
struct InlineNote: View {
    enum Tone { case soft, warn }
    var text: String
    var tone: Tone = .soft

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Image(systemName: tone == .warn ? "exclamationmark.circle" : "info.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tone == .warn ? Palette.warn : Palette.inkSoft)
                .accessibilityHidden(true)
            Text(text).font(HDFont.sub).foregroundStyle(Palette.ink)
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone == .warn ? Palette.warnSoft : Palette.card, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                .strokeBorder(tone == .warn ? Color.clear : Palette.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Something went wrong, said plainly, with the one thing to do next.
struct FlowErrorCard: View {
    var message: String
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(message).font(HDFont.body).foregroundStyle(Palette.ink)
            Button(action: { Haptics.light(); action() }) {
                Text(actionTitle).font(HDFont.subStrong).foregroundStyle(Palette.lacquer)
                    .frame(minHeight: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(Space.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.lacquerSoft, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

/// The Apple Pay mark, drawn by hand because PassKit's button needs entitlements.
/// Apple's guidelines want it black with white type, so these two colours are on purpose.
struct ApplePayPill: View {
    var height: CGFloat = 32

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "apple.logo").font(.system(size: height * 0.42, weight: .medium))
            Text("Pay").font(.system(size: height * 0.5, weight: .medium))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, height * 0.45)
        .frame(height: height)
        .background(Color.black, in: Capsule())
        .accessibilityLabel("Apple Pay")
    }
}

/// A secondary-looking label for ShareLink and other system buttons.
struct SecondaryLabel: View {
    var title: String
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let symbol { Image(systemName: symbol) }
            Text(title)
        }
        .font(HDFont.bodyStrong)
        .foregroundStyle(Palette.ink)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Palette.card, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
    }
}

/// A row in a summary: soft label on the left, value on the right, optional Change.
struct SummaryRow: View {
    var label: String
    var value: String
    var detail: String? = nil
    var changeTitle: String? = nil
    var onChange: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            Text(label).font(HDFont.sub).foregroundStyle(Palette.inkSoft).frame(width: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(HDFont.body).foregroundStyle(Palette.ink)
                if let detail { Text(detail).font(HDFont.caption).foregroundStyle(Palette.inkSoft) }
            }
            Spacer(minLength: 0)
            if let changeTitle, let onChange {
                Button(action: { Haptics.light(); onChange() }) {
                    Text(changeTitle).font(HDFont.subStrong).foregroundStyle(Palette.lacquer)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(changeTitle) \(label.lowercased())")
            }
        }
    }
}

// MARK: - Model helpers used only by the booking screens

extension Pro {
    /// "an hour", "20 minutes", "2 hours". For "usually replies within {time}".
    var replyWindow: String {
        switch responseMinutes {
        case ..<50: return "\(max(responseMinutes, 5)) minutes"
        case 50...75: return "an hour"
        default:
            let hours = max(2, Int((Double(responseMinutes) / 60).rounded()))
            return "\(hours) hours"
        }
    }

    /// "Coburg and 10 km around"
    var travelAreaLine: String { "\(suburb) and \(Int(travelRadiusKm.rounded())) km around" }

    /// Whether an address sits inside her travel area.
    func comesTo(_ address: Address) -> Bool {
        distanceKm(from: CLLocationCoordinate2D(latitude: address.latitude, longitude: address.longitude)) <= travelRadiusKm + 0.25
    }
}

extension Address {
    /// "Home · 14 Rae St, Fitzroy North"
    var labelled: String { label.isEmpty ? short : "\(label) · \(short)" }
}

extension String {
    /// "She's booked" → "she's booked", for reading out mid-sentence.
    var lowercasedFirst: String {
        guard let first = first else { return self }
        return first.lowercased() + dropFirst()
    }
}

extension Date {
    /// "Nothing free today." / "Nothing free on Thu 12 Mar."
    var nothingFreeLine: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "Nothing free today." }
        if cal.isDateInTomorrow(self) { return "Nothing free tomorrow." }
        return "Nothing free on \(shortDay)."
    }
}
