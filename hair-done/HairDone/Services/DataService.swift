import Foundation
import CoreLocation

/// Everything the app reads or writes goes through here. `MockDataService` is the
/// in-memory implementation the app ships with; `SupabaseDataService` is the stub
/// for the real backend in `supabase/`.
protocol DataService: AnyObject {
    // Session
    func signIn(phone: String) async throws -> Client
    func signInWithApple() async throws -> Client
    func currentClient() async -> Client?
    func currentPro() async -> Pro?
    func updateClient(_ client: Client) async throws
    func updatePro(_ pro: Pro) async throws

    // Discovery
    func pros(near coordinate: CLLocationCoordinate2D, category: Category?) async throws -> [Pro]
    func pro(id: String) async throws -> Pro?
    func slots(for pro: Pro, on day: Date, minutes: Int) async throws -> [TimeSlot]

    // Bookings
    func bookings(clientID: String) async throws -> [Booking]
    func bookings(proID: String) async throws -> [Booking]
    func createBooking(_ draft: BookingDraft) async throws -> Booking
    func updateStatus(bookingID: String, to status: BookingStatus, reason: String?) async throws -> Booking
    func reschedule(bookingID: String, to start: Date) async throws -> Booking
    func submitReview(bookingID: String, rating: Int, text: String, tipCents: Int) async throws -> Booking

    // Messaging
    func threads(userID: String) async throws -> [MessageThread]
    func send(text: String, threadID: String, senderID: String) async throws -> MessageThread

    // Pro side
    func payouts(proID: String) async throws -> [Payout]
}

/// What the booking flow builds up before it's confirmed.
struct BookingDraft {
    var pro: Pro
    var services: [Service] = []
    var start: Date? = nil
    var address: Address? = nil
    var notes: String = ""
    var inspoSeeds: [Int] = []
    var paymentMethod: PaymentMethod? = nil

    var minutes: Int { services.reduce(0) { $0 + $1.minutes } }
    var servicesCents: Int { services.reduce(0) { $0 + $1.priceCents } }
    var price: PriceBreakdown { PriceBreakdown(servicesCents: servicesCents, travelFeeCents: pro.travelFeeCents) }
    var isComplete: Bool { !services.isEmpty && start != nil && address != nil && paymentMethod != nil }
}

enum DataError: LocalizedError {
    case notSignedIn
    case notFound
    case slotTaken
    case network

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "You're not signed in."
        case .notFound: return "We couldn't find that one."
        case .slotTaken: return "Someone just took that time. Here's what's still free."
        case .network: return "That didn't go through. Check your connection and try again."
        }
    }
}
