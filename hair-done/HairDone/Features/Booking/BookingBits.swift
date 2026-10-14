import SwiftUI
import CoreLocation

// Small shared pieces for the booking flow, the reschedule sheet, the two editors and the profile's
// Book bar. Built from the shared tokens (Palette, HDFont, Radius); no private colours or type.

// MARK: - Flow header

/// The paper chrome over steps 1 to 4: a bare chevron and a bare close in ink, "2 OF 5" centred as an
/// eyebrow, and a 1pt ink line across the full width that fills as she goes.
struct FlowHeader: View {
    /// Zero-based step.
    var step: Int
    var total: Int
    var canGoBack: Bool
    var onBack: () -> Void
    var onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("\(step + 1) of \(total)")
                    .eyebrowStyle()
                    .monospacedDigit()
                    .accessibilityLabel("Step \(step + 1) of \(total)")
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 0) {
                    if canGoBack {
                        IconButton(symbol: "chevron.left", label: "Back", action: onBack)
                    } else {
                        Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
                    }
                    Spacer(minLength: 0)
                    IconButton(symbol: "xmark", label: "Close", action: onClose)
                }
                .padding(.horizontal, Space.gutter - 12)
            }
            .frame(minHeight: 44)
            .padding(.top, Space.s)
            .padding(.bottom, Space.xs)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Palette.lineStrong)
                    Rectangle().fill(Palette.ink)
                        .frame(width: proxy.size.width * CGFloat(step + 1) / CGFloat(max(total, 1)))
                }
            }
            .frame(height: 1)
            .animation(reduceMotion ? nil : Motion.spring, value: step)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - The ink Book bar

/// The profile's ink bar, carried through the booking flow: her name in serif and a summary on the
/// left, a squared paper action on the right. Stacks at accessibility sizes instead of shrinking.
///
///     BookBar(name: "Kiara", summary: "$95 · 1 h 15", detail: "Free today from 5:00 pm", actionTitle: "Book") { book() }
struct BookBar: View {
    var name: String
    var summary: String? = nil
    var detail: String? = nil
    var actionTitle: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    /// What VoiceOver reads for the left side. Defaults to the visible words.
    var accessibilityText: String? = nil
    /// For the button. Defaults to the title.
    var actionAccessibilityLabel: String? = nil
    var action: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Space.m) {
                    words
                    button.frame(maxWidth: .infinity)
                }
            } else {
                HStack(alignment: .center, spacing: Space.l) {
                    words.frame(maxWidth: .infinity, alignment: .leading)
                    button
                }
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.vertical, 10)
        .background(Palette.inkGround.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Palette.inkLine).frame(height: 0.5) }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 2) {
            (Text(verbatim: name).font(HDFont.nameBar).foregroundColor(Palette.onInk)
                + Text(verbatim: summary.map { "  \($0)" } ?? "").font(HDFont.sub.monospacedDigit()).foregroundColor(Palette.onInkSoft))
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.numericText())
            if let detail {
                Text(verbatim: detail)
                    .font(HDFont.caption)
                    .foregroundStyle(Palette.onInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText ?? [name, summary, detail].compactMap { $0 }.joined(separator: ", "))
    }

    private var button: some View {
        Button {
            guard isEnabled, !isLoading else { return }
            Haptics.medium()
            action()
        } label: {
            ZStack {
                if isLoading {
                    ProgressView().tint(Palette.inkGround)
                } else {
                    Text(verbatim: actionTitle)
                        .font(HDFont.bodyStrong)
                        .multilineTextAlignment(.center)
                }
            }
            .foregroundStyle(isEnabled ? Palette.inkGround : Palette.onInkSoft)
            .padding(.horizontal, Space.l)
            .padding(.vertical, 10)
            .frame(minWidth: 116, minHeight: 44)
            .background(isEnabled ? Palette.onInk : Palette.onInk.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(PressLift())
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(actionAccessibilityLabel ?? actionTitle)
    }
}

// MARK: - Notes

/// A quiet line under a control: "She's off Sundays." With `.warn`, a 6pt warn dot leads it.
/// No box, no tint. (Kept under its old name so other screens' call sites still compile.)
struct InlineNote: View {
    enum Tone { case soft, warn }
    var text: String
    var tone: Tone = .soft

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            if tone == .warn {
                Circle().fill(Palette.warn).frame(width: 6, height: 6)
                    .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 1 }
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(HDFont.sub)
                .foregroundStyle(tone == .warn ? Palette.ink : Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The same line on an ink ground: warn dot, paper type.
struct InkNote: View {
    var text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Circle().fill(Palette.warn).frame(width: 6, height: 6)
                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 1 }
                .accessibilityHidden(true)
            Text(text)
                .font(HDFont.sub)
                .foregroundStyle(Palette.onInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Ink sheets

/// Top of a sheet that sits on ink (Pay with, Add a card): serif 28 in paper and a bare paper close.
struct InkSheetHeader: View {
    var title: String
    var subtitle: String? = nil
    var onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Space.s) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(HDFont.titleSmall)
                    .foregroundStyle(Palette.onInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(HDFont.sub)
                        .foregroundStyle(Palette.onInkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 6)
            Spacer(minLength: 0)
            IconButton(symbol: "xmark", label: "Close", tint: Palette.onInk, action: onClose)
                .padding(.trailing, -12)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, 14)
        .padding(.bottom, 8)
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
        .background(Color.black, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Palette.inkLine, lineWidth: 0.5))
        .accessibilityLabel("Apple Pay")
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

    /// Whether clients can book her right now, as far as the app can tell. The server has the last word.
    var isTakingBookings: Bool { isActive && !isClosed && isOnboarded }
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
    /// "today", "tomorrow" or "Thu 12 Mar", for use mid-sentence.
    var friendlyDayInSentence: String {
        let day = friendlyDay
        return (day == "Today" || day == "Tomorrow" || day == "Yesterday") ? day.lowercased() : day
    }

    /// "Nothing free today." / "Nothing free on Thu 12 Mar."
    var nothingFreeLine: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "Nothing free today." }
        if cal.isDateInTomorrow(self) { return "Nothing free tomorrow." }
        return "Nothing free on \(shortDay)."
    }

    /// "5 pm", "5:30 pm": a time said the way people say it, for "Free from 5 pm".
    var spokenClock: String {
        let m = hourOfDay * 60 + minuteOfHour
        return TimeRange(startMinutes: m, endMinutes: m).clock(m)
    }
}

/// "1 h 15", "1 h", "45 min": the short duration on the price list and the ticket.
enum ShortDuration {
    static func label(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h) h" }
        return "\(h) h " + String(format: "%02d", m)
    }
}
