import Foundation

/// Hair Done's own details for receipts. It isn't registered for GST, so a receipt never says
/// "tax invoice" and every one says "No GST included". Matches the site's terms.
enum HairDoneBusiness {
    static let name = "Hair Done"
    static let abn = "45 281 131 814"
    static let operatorName = "Keith Chinyanda"
    static let place = "Melbourne VIC"
    static let email = "hello@hairdonenailsdone.app"
    static let terms = "hairdonenailsdone.app/terms"
}

/// What a paid booking's receipt needs from the server that the app doesn't hold: her ABN (private
/// to everyone but her clients' receipts), the card it was paid on, and when.
struct ReceiptDetails: Hashable {
    var proABN: String?
    var card: String?
    var paidAt: Date?
    /// The server can email receipts (Resend is set up).
    var canEmail: Bool
}

/// One line on a receipt: who it's from decides the section.
struct ReceiptLine: Hashable {
    var name: String
    var note: String = ""
    var cents: Int
    /// "$60.00", or "−$5.00" for a discount.
    var amount: String { cents < 0 ? "−" + Money.format(-cents, alwaysCents: true) : Money.format(cents, alwaysCents: true) }
}

extension Booking {
    /// Her lines: the services, travel and the tip.
    func receiptProLines(proFirst: String) -> [ReceiptLine] {
        var lines = services.map { ReceiptLine(name: $0.name, note: $0.durationLabel, cents: $0.priceCents) }
        if price.travelFeeCents > 0 { lines.append(ReceiptLine(name: "Travel fee", cents: price.travelFeeCents)) }
        if price.tipCents > 0 { lines.append(ReceiptLine(name: "Tip", note: "100% to \(proFirst)", cents: price.tipCents)) }
        return lines
    }

    /// Hair Done's lines: the booking fee, less any discount (which comes off our side).
    var receiptHairDoneLines: [ReceiptLine] {
        var lines = [ReceiptLine(name: "Booking fee", cents: price.bookingFeeCents)]
        if price.discountCents > 0 { lines.append(ReceiptLine(name: "Discount", cents: -price.discountCents)) }
        return lines
    }

    /// "Gel manicure with Hannah W.", or "Hannah W., 3 services".
    func receiptTitle(proName: String) -> String {
        services.count == 1 ? "\(services[0].name) with \(proName)" : "\(proName), \(services.count) services"
    }

    /// The small print under every receipt.
    static func receiptFooter(proFirst: String) -> String {
        "No GST included. \(proFirst) provides the service; Hair Done arranges the booking and payment.\n"
            + "Hair Done is run by \(HairDoneBusiness.operatorName) · \(HairDoneBusiness.place) · "
            + "\(HairDoneBusiness.email) · \(HairDoneBusiness.terms)"
    }
}

extension ReceiptDetails {
    /// "Visa •••• 4242 · 21 Oct 2026, 2:58 pm", or whichever half we know.
    var paidLine: String? {
        let parts = [card, paidAt.map { "\($0.longDate), \($0.clock)" }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
