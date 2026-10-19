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

    /// What she pays if she cancels right now, by the spec (product-spec §5):
    /// requested, or confirmed and 24 hours or more out: nothing. Confirmed inside 24 hours, or
    /// once the pro is on her way: half the services and travel. Once the pro has arrived (or
    /// started): the full price and the booking fee.
    var cancelChargeCents: Int {
        let work = price.servicesCents + price.travelFeeCents
        switch status {
        case .confirmed:
            if hoursUntil >= Double(Fees.freeCancellationHours) { return 0 }
            return Int((Double(work) * Fees.lateCancellationRate).rounded())
        case .onHerWay:
            return Int((Double(work) * Fees.lateCancellationRate).rounded())
        case .arrived, .inProgress:
            return work + price.bookingFeeCents
        default:
            return 0
        }
    }

    /// The client can cancel up to the moment the work starts.
    var clientCanCancel: Bool { [.requested, .confirmed, .onHerWay, .arrived].contains(status) }

    /// The line on the cancel sheet, with the exact charge. Copy deck `detail.cancel.body.*`.
    func cancelBody(proName: String) -> String {
        let charge = cancelChargeCents
        switch status {
        case .requested:
            return "She hasn't confirmed yet, so nothing's charged."
        case .onHerWay:
            return "\(proName)'s already on her way, so she keeps half, \(Money.format(charge)). The rest drops off your card."
        case .arrived, .inProgress:
            return "\(proName)'s at your door, so it's the full price and the \(Money.format(price.bookingFeeCents)) booking fee."
        default:
            if charge == 0 { return "More than 24 hours out, so it's free. The hold drops off your card in a few days." }
            return "Under 24 hours. \(proName) keeps half, \(Money.format(charge)). She's already turned down other work for you."
        }
    }

    /// Button title on the cancel sheet. Carries the amount when there is one.
    var cancelButtonTitle: String {
        let charge = cancelChargeCents
        return charge == 0 ? "Cancel it" : "Cancel and pay \(Money.format(charge))"
    }

    /// Toast after cancelling. Copy deck `detail.cancel.done.*`.
    func cancelDoneLine(proName: String) -> String {
        let charge = cancelChargeCents
        if charge == 0 { return "Cancelled. Nothing charged." }
        if status == .arrived || status == .inProgress { return "Cancelled. \(Money.format(charge)) to \(proName)." }
        return "Cancelled. \(Money.format(charge)) to \(proName), the rest drops off your card."
    }

    /// When the card is charged if she doesn't pay at done: 12 hours after the pro marked it done.
    var autoChargeAt: Date {
        let doneAt = events.last(where: { $0.status == .done })?.at ?? end
        return doneAt.adding(hours: Fees.autoCaptureHours)
    }

    /// The plain-text receipt for Share: the same lines as the sheet and the email.
    func receiptText(proName: String, proFirst: String, details: ReceiptDetails?) -> String {
        let row = { (l: ReceiptLine) in "\(l.name)\(l.note.isEmpty ? "" : " (\(l.note))")  \(l.amount)" }
        var lines = ["Hair Done receipt \(reference)", receiptTitle(proName: proName),
                     "\(start.shortDay), \(start.clock)", address.full, ""]
        lines.append("From \(proName)" + (details?.proABN.map { " · ABN \($0)" } ?? ""))
        lines += receiptProLines(proFirst: proFirst).map(row)
        lines += ["", "From Hair Done · ABN \(HairDoneBusiness.abn)"]
        lines += receiptHairDoneLines.map(row)
        lines += ["", "Total paid  \(Money.format(price.clientTotalCents, alwaysCents: true))"]
        if let paid = details?.paidLine { lines.append(paid) }
        lines += ["", Booking.receiptFooter(proFirst: proFirst)]
        return lines.joined(separator: "\n")
    }

    /// What you'd text a friend so she knows where you are.
    func shareText(proName: String) -> String {
        "I've got \(proName) coming \(start.hdSpokenDay) at \(start.clock), \(address.short). Booked on Hair Done. Booking \(reference)."
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

    /// Not finished on either side: still to happen, or done and waiting on payment.
    var isUnfinished: Bool { status.isUpcoming || status == .done }

    /// Her pro's photo for this booking: one in the booked category, else her pinned or first photo,
    /// else her avatar. Nil when there's none of hers (or her card hasn't loaded): callers show the
    /// neutral `NoPhotoTile`. Never a bundled stock photo presented as hers.
    func coverItem(pro: Pro?) -> WorkItem? {
        guard let pro else { return nil }
        let matching = pro.work.filter { $0.category == primaryCategory }
        if let pick = matching.first(where: { $0.isPinned }) ?? matching.first { return pick }
        return pro.homeCover
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

    /// For the middle of a sentence: "today", "tomorrow", "on Saturday", "on Sat 25 Oct".
    var hdSpokenDay: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "today" }
        if cal.isDateInTomorrow(self) { return "tomorrow" }
        if cal.isDateInYesterday(self) { return "yesterday" }
        let days = cal.dateComponents([.day], from: Date().startOfDay, to: startOfDay).day ?? 99
        let f = DateFormatter(); f.locale = Locale(identifier: "en_AU")
        f.dateFormat = (days > 0 && days < 7) ? "EEEE" : "EEE d MMM"
        return "on " + f.string(from: self)
    }

    /// "Thursday 23 October"
    var hdLongDay: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_AU"); f.dateFormat = "EEEE d MMMM"; return f.string(from: self)
    }

    /// "March 2026"
    var hdMonthYear: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_AU"); f.dateFormat = "MMMM yyyy"; return f.string(from: self)
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

/// A status dot that breathes, for the booking that's happening today. Still under Reduce Motion.
struct LiveDot: View {
    var color: Color = Palette.success
    var size: CGFloat = 6
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.3))
                .frame(width: size * 2.4, height: size * 2.4)
                .scaleEffect(on ? 1.1 : 0.5)
                .opacity(on ? 0 : 0.9)
            Circle().fill(color).frame(width: size, height: size)
        }
        .frame(width: size * 2.4, height: size * 2.4)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { on = true }
        }
        .accessibilityHidden(true)
    }
}

/// A photo that fills its frame, cropped, at the photo radius. Nil shows the neutral `NoPhotoTile`.
/// The same object as Home's `HomePhoto` (kept by name for the thread header).
struct BookingPhoto: View {
    var item: WorkItem?
    var cornerRadius: CGFloat = Radius.photo

    var body: some View {
        HomePhoto(item: item, cornerRadius: cornerRadius)
    }
}

/// An eyebrow status on paper: 6pt dot in the status colour, tracked caps in ink. Same rules as
/// `StatusBadge`, but on-the-way states get the success dot (lacquer is for unread and Pay only).
struct BookingStatusEyebrow: View {
    var status: BookingStatus
    var live = false

    var body: some View {
        HStack(spacing: 6) {
            if !status.isCancelled {
                if live { LiveDot(color: color) } else { Circle().fill(color).frame(width: 6, height: 6) }
            }
            Text(status.label)
                .eyebrowStyle(color: status.isCancelled ? Palette.inkSoft : Palette.ink)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(status.label)")
    }

    private var color: Color {
        switch status {
        case .requested: return Palette.warn
        default: return Palette.success
        }
    }
}
