import Foundation
import SwiftUI

/// Where the pro comes to.
struct Address: Identifiable, Hashable, Codable {
    let id: String
    var label: String
    var line1: String
    var suburb: String
    var state: String = "VIC"
    var postcode: String
    var latitude: Double
    var longitude: Double
    /// "Buzz 12, dog is friendly"
    var instructions: String = ""

    var short: String { "\(line1), \(suburb)" }
    var full: String { "\(line1), \(suburb) \(state) \(postcode)" }
}

struct PaymentMethod: Identifiable, Hashable, Codable {
    enum Kind: String, Codable { case card, applePay }
    let id: String
    var kind: Kind
    var brand: String
    var last4: String
    var expiry: String
    var isDefault: Bool

    var label: String {
        switch kind {
        case .applePay: return "Apple Pay"
        case .card: return "\(brand) ending \(last4)"
        }
    }
}

/// The client's account.
struct Client: Identifiable, Hashable, Codable {
    let id: String
    var firstName: String
    var lastName: String
    var phone: String
    var email: String
    var addresses: [Address]
    var paymentMethods: [PaymentMethod]
    var favouriteProIDs: Set<String>
    var seed: Int
    var notificationsOn: Bool = true
    var joined: Date

    var fullName: String { "\(firstName) \(lastName)" }
    var defaultAddress: Address? { addresses.first }
    var defaultPayment: PaymentMethod? { paymentMethods.first(where: \.isDefault) ?? paymentMethods.first }
}

/// Every state a booking can be in. See docs/product-spec.md for who moves it where.
enum BookingStatus: String, Codable, CaseIterable, Hashable {
    case requested, confirmed, onHerWay, arrived, inProgress, done, paid
    case cancelledByClient, cancelledByPro, declined, noShow

    /// Short label for chips and lists.
    var label: String {
        switch self {
        case .requested: return "Requested"
        case .confirmed: return "Confirmed"
        case .onHerWay: return "On her way"
        case .arrived: return "She's here"
        case .inProgress: return "In progress"
        case .done: return "Done"
        case .paid: return "Paid"
        case .cancelledByClient: return "You cancelled"
        case .cancelledByPro: return "She cancelled"
        case .declined: return "Declined"
        case .noShow: return "Missed"
        }
    }

    /// What the client sees under the status.
    func clientLine(pro: String) -> String {
        switch self {
        case .requested: return "Waiting on \(pro). She usually replies in under an hour."
        case .confirmed: return "\(pro) has locked it in."
        case .onHerWay: return "\(pro) is on her way."
        case .arrived: return "\(pro) is at the door."
        case .inProgress: return "Happening now."
        case .done: return "Done. Charging your card now."
        case .paid: return "Paid. Receipt's in your inbox."
        case .cancelledByClient: return "You cancelled this one."
        case .cancelledByPro: return "\(pro) had to cancel. You weren't charged."
        case .declined: return "\(pro) couldn't make it this time."
        case .noShow: return "Missed. Charged in full."
        }
    }

    /// What the pro sees.
    func proLine(client: String) -> String {
        switch self {
        case .requested: return "\(client) is waiting on you."
        case .confirmed: return "Locked in."
        case .onHerWay: return "You're on your way."
        case .arrived: return "You've arrived."
        case .inProgress: return "In progress."
        case .done: return "Done. Your payout lands tomorrow."
        case .paid: return "Paid. It'll be in your next payout."
        case .cancelledByClient: return "\(client) cancelled."
        case .cancelledByPro: return "You cancelled."
        case .declined: return "You declined."
        case .noShow: return "Client didn't show."
        }
    }

    var isUpcoming: Bool {
        switch self {
        case .requested, .confirmed, .onHerWay, .arrived, .inProgress: return true
        default: return false
        }
    }
    var isActiveDay: Bool { [.onHerWay, .arrived, .inProgress].contains(self) }
    var isCancelled: Bool { [.cancelledByClient, .cancelledByPro, .declined, .noShow].contains(self) }
    var isFinished: Bool { [.done, .paid].contains(self) }

    var color: Color {
        switch self {
        case .requested: return Palette.warn
        case .confirmed, .onHerWay, .arrived, .inProgress: return Palette.lacquer
        case .done, .paid: return Palette.success
        case .cancelledByClient, .cancelledByPro, .declined, .noShow: return Palette.inkSoft
        }
    }
    var softColor: Color {
        switch self {
        case .requested: return Palette.warnSoft
        case .confirmed, .onHerWay, .arrived, .inProgress: return Palette.lacquerSoft
        case .done, .paid: return Palette.successSoft
        default: return Palette.line
        }
    }

    /// The happy-path order, for the timeline.
    static let timeline: [BookingStatus] = [.requested, .confirmed, .onHerWay, .arrived, .done, .paid]
}

struct StatusEvent: Identifiable, Hashable, Codable {
    let id: String
    var status: BookingStatus
    var at: Date
}

/// The money on a booking, all in cents. Built once at booking time so it never drifts.
struct PriceBreakdown: Hashable, Codable {
    var servicesCents: Int
    var travelFeeCents: Int
    var bookingFeeCents: Int = Fees.bookingFeeCents
    var tipCents: Int = 0
    var discountCents: Int = 0

    /// What the client pays.
    var clientTotalCents: Int { servicesCents + travelFeeCents + bookingFeeCents + tipCents - discountCents }
    /// What Hair Done keeps from the pro's side.
    var platformFeeCents: Int { Int((Double(servicesCents + travelFeeCents) * Fees.platformRate).rounded()) }
    /// What lands in the pro's payout.
    var proPayoutCents: Int { servicesCents + travelFeeCents - platformFeeCents + tipCents }
}

enum Fees {
    static let bookingFeeCents = 300
    static let platformRate = 0.12
    static let freeCancellationHours = 24
    static let lateCancellationRate = 0.5
    static let autoCaptureHours = 12
    static let autoDeclineHours = 2
}

struct Booking: Identifiable, Hashable, Codable {
    let id: String
    var proID: String
    var clientID: String
    var services: [Service]
    var start: Date
    var address: Address
    var notes: String
    var inspoSeeds: [Int]
    var status: BookingStatus
    var price: PriceBreakdown
    var createdAt: Date
    var events: [StatusEvent]
    var review: Review? = nil
    var declineReason: String? = nil
    var paymentMethodID: String? = nil
    /// A short code you can read out or share. "HD-4K2P"
    var reference: String

    var minutes: Int { services.reduce(0) { $0 + $1.minutes } }
    var end: Date { start.adding(minutes: minutes) }
    var servicesLine: String { services.map(\.name).joined(separator: " + ") }
    var isToday: Bool { Calendar.current.isDateInToday(start) }
    var primaryCategory: Category { services.first?.category ?? .hair }

    /// Hours until it starts (negative if it's started).
    var hoursUntil: Double { start.timeIntervalSinceNow / 3600 }

    /// What the client owes if she cancels right now.
    var cancellationChargeCents: Int {
        guard status.isUpcoming, status != .requested else { return 0 }
        if status == .arrived || status == .inProgress { return price.servicesCents + price.travelFeeCents + price.bookingFeeCents }
        if hoursUntil >= Double(Fees.freeCancellationHours) { return 0 }
        return Int((Double(price.servicesCents + price.travelFeeCents) * Fees.lateCancellationRate).rounded())
    }

    static func == (lhs: Booking, rhs: Booking) -> Bool { lhs.id == rhs.id && lhs.status == rhs.status && lhs.start == rhs.start && lhs.review == rhs.review && lhs.price == rhs.price }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Messaging

struct Message: Identifiable, Hashable, Codable {
    let id: String
    var threadID: String
    var senderID: String
    var text: String
    var sentAt: Date
    var isSystem: Bool = false
}

struct MessageThread: Identifiable, Hashable, Codable {
    let id: String
    var bookingID: String
    var proID: String
    var clientID: String
    var messages: [Message]
    var unreadForClient: Int = 0
    var unreadForPro: Int = 0

    var last: Message? { messages.last }
}

// MARK: - Earnings

struct Payout: Identifiable, Hashable, Codable {
    enum Status: String, Codable { case pending, paid }
    let id: String
    var amountCents: Int
    var date: Date
    var status: Status
    var bookingIDs: [String]
}
