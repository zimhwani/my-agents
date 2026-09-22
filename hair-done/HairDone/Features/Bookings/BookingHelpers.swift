import SwiftUI
import CoreLocation

/// Small shared helpers for the Bookings, Inbox and You screens. Copy here follows docs/copy-deck.md.

extension Booking {
    /// "BIAB overlay with Kiara", or "Gel manicure and 2 more with Kiara".
    func cardTitle(proName: String) -> String {
        guard let first = services.first else { return "Booking with \(proName)" }
        if services.count == 1 { return "\(first.name) with \(proName)" }
        return "\(first.name) and \(services.count - 1) more with \(proName)"
    }

    /// "Today, 6:15 pm · Fitzroy North"
    var whenWhereLine: String { "\(start.friendlyDayTime) · \(address.suburb)" }

    /// The line on the cancel sheet, with the exact charge. Copy deck `detail.cancel.body.*`.
    func cancelBody(proName: String) -> String {
        if status == .requested { return "She hasn't confirmed yet, so nothing's charged." }
        let charge = cancellationChargeCents
        if charge == 0 { return "More than 24 hours out, so it's free. The hold drops off your card in a few days." }
        return "Under 24 hours. \(proName) keeps half, \(Money.format(charge)). She's already turned down other work for you."
    }

    /// Button title on the cancel sheet. Carries the amount when there is one.
    var cancelButtonTitle: String {
        let charge = cancellationChargeCents
        return charge == 0 ? "Cancel it" : "Cancel and pay \(Money.format(charge))"
    }

    /// Toast after cancelling. Copy deck `detail.cancel.done.*`.
    func cancelDoneLine(proName: String) -> String {
        let charge = cancellationChargeCents
        if charge == 0 { return "Cancelled. Nothing charged." }
        return "Cancelled. \(Money.format(charge)) to \(proName), the rest drops off your card."
    }

    /// A plain-text receipt for sharing.
    func receiptText(proName: String) -> String {
        var lines: [String] = []
        lines.append("Hair Done receipt \(reference)")
        lines.append("\(proName), \(start.longDate) at \(start.clock)")
        lines.append(address.full)
        lines.append("")
        for s in services { lines.append("\(s.name) (\(s.durationLabel))  \(Money.format(s.priceCents))") }
        lines.append("Travel fee  \(Money.format(price.travelFeeCents))")
        lines.append("Hair Done fee  \(Money.format(price.bookingFeeCents))")
        if price.tipCents > 0 { lines.append("Tip  \(Money.format(price.tipCents))") }
        lines.append("Total  \(Money.format(price.clientTotalCents))")
        lines.append("")
        lines.append("Paid in the app. Questions? Message us from Help.")
        return lines.joined(separator: "\n")
    }

    /// What you'd text a friend so she knows where you are.
    func shareText(proName: String) -> String {
        "I've got \(proName) coming \(start.friendlyDayInSentence) at \(start.clock), \(address.short). Booked on Hair Done. Booking \(reference)."
    }

    /// Rough minutes for her to drive from her base to your door. Used for the on-her-way line.
    func travelMinutes(from pro: Pro) -> Int {
        let km = pro.distanceKm(from: .init(latitude: address.latitude, longitude: address.longitude))
        return max(5, Int((km / 28 * 60).rounded()) + 5)
    }

    /// When each step on the timeline happened, if it has.
    func eventTime(for status: BookingStatus) -> Date? {
        events.first { $0.status == status }?.at
    }
}

extension BookingStatus {
    /// Step title on the detail timeline. Copy deck `detail.timeline.*`.
    var timelineTitle: String {
        switch self {
        case .requested: return "Requested"
        case .confirmed: return "Confirmed"
        case .onHerWay: return "On her way"
        case .arrived: return "Here"
        case .done: return "Done"
        case .paid: return "Paid"
        case .inProgress: return "In progress"
        case .cancelledByClient: return "You cancelled"
        case .cancelledByPro: return "She cancelled"
        case .declined: return "Declined"
        case .noShow: return "Missed"
        }
    }

    /// Where this status sits on the happy path. `inProgress` sits with `arrived`.
    var timelineIndex: Int? {
        if self == .inProgress { return BookingStatus.timeline.firstIndex(of: .arrived) }
        return BookingStatus.timeline.firstIndex(of: self)
    }
}

extension Date {
    /// "Just now", "2 min", "3 h", "Yesterday", "Tue", "24 Sep". For inbox rows.
    var hdRelative: String {
        let seconds = Date().timeIntervalSince(self)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(Int(seconds / 60)) min" }
        if Calendar.current.isDateInToday(self) { return "\(Int(seconds / 3600)) h" }
        if Calendar.current.isDateInYesterday(self) { return "Yesterday" }
        if seconds < 6 * 86400 {
            let f = DateFormatter(); f.locale = Locale(identifier: "en_AU"); f.dateFormat = "EEE"; return f.string(from: self)
        }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_AU"); f.dateFormat = "d MMM"; return f.string(from: self)
    }

    var yearNumber: Int { Calendar.current.component(.year, from: self) }
}

extension String {
    /// A stable number from a string, for avatar tints. Same every launch, unlike hashValue.
    var hdSeed: Int { unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF } }

    /// "3/22 Lygon St" → "3". Nothing for a plain street address.
    var unitNumber: String? {
        guard let slash = firstIndex(of: "/") else { return nil }
        let unit = self[..<slash].trimmingCharacters(in: .whitespaces)
        return unit.isEmpty || unit.count > 4 ? nil : unit
    }
}

/// A lacquer dot that breathes. For the booking that's happening today.
struct LiveDot: View {
    var color: Color = Palette.lacquer
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.28))
                .frame(width: 16, height: 16)
                .scaleEffect(on ? 1.15 : 0.6)
                .opacity(on ? 0 : 0.9)
            Circle().fill(color).frame(width: 8, height: 8)
        }
        .frame(width: 16, height: 16)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { on = true }
        }
        .accessibilityHidden(true)
    }
}
