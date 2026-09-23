import Foundation
import CoreLocation

/// Everything the app reads or writes goes through here. `SupabaseDataService` is the real backend
/// in `supabase/`; `MockDataService` is the in-memory stand-in for previews and for running without keys.
protocol DataService: AnyObject {
    // Session
    /// Texts a six-digit code to an Australian mobile ("0412 345 678").
    func sendCode(phone: String) async throws
    func verifyCode(phone: String, code: String) async throws -> Client
    func signInWithApple(_ credential: AppleCredential) async throws -> Client
    /// The signed-in client, if there's a session to pick up. Nil when signed out.
    func currentClient() async -> Client?
    func currentPro() async -> Pro?
    /// Saves the client: profile, contact details, addresses, card defaults and favourites.
    func updateClient(_ client: Client) async throws
    /// Saves her pro profile, services, work, hours and days off. Returns what was saved.
    func updatePro(_ pro: Pro) async throws -> Pro
    func signOut() async
    func deleteAccount() async throws

    // Discovery
    func pros(near coordinate: CLLocationCoordinate2D, category: Category?) async throws -> [Pro]
    /// Her whole profile: services, work, hours and reviews.
    func pro(id: String) async throws -> Pro?
    /// Pros you've booked or saved, for Book again and favourites.
    func proCards(ids: [String]) async throws -> [Pro]
    func slots(for pro: Pro, on day: Date, minutes: Int) async throws -> [TimeSlot]
    /// First names of clients who've booked the signed-in pro.
    func clientNames(ids: [String]) async throws -> [String: String]

    // Bookings
    func bookings(clientID: String) async throws -> [Booking]
    func bookings(proID: String) async throws -> [Booking]
    func booking(id: String) async throws -> Booking?
    /// Makes the booking, not yet paid for. `PaymentService.checkout` takes the money next.
    func createBooking(_ draft: BookingDraft) async throws -> Booking
    /// Checkout didn't finish. The real server lets an unpaid booking lapse by itself.
    func abandonBooking(id: String) async
    func updateStatus(bookingID: String, to status: BookingStatus, reason: String?) async throws -> Booking
    func reschedule(bookingID: String, to start: Date) async throws -> Booking
    /// Pays for a done booking (with the tip) if it isn't paid yet, then leaves the review.
    func submitReview(bookingID: String, rating: Int, text: String, tipCents: Int) async throws -> Booking
    /// "Something wrong?" on a done booking: holds off the charge while a person looks.
    func flagBooking(bookingID: String, detail: String) async throws -> Booking

    // Messaging
    func threads(userID: String) async throws -> [MessageThread]
    func thread(id: String) async throws -> MessageThread?
    func send(text: String, threadID: String, senderID: String) async throws -> MessageThread
    func markRead(threadID: String, asPro: Bool) async

    // Safety
    func blockedIDs() async throws -> Set<String>
    func block(userID: String) async throws
    func report(userID: String, bookingID: String?, reason: String, detail: String) async throws

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
    case server
    case wrongCode
    case tooManyTries
    case codeNotSent
    case outsideTravelArea
    case servicesChanged
    case ownBooking
    case alreadyMoved
    case cantReschedule
    case liveBooking
    case payFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "You're not signed in."
        case .notFound: return "We couldn't find that one."
        case .slotTaken: return "Someone just took that time. Here's what's still free."
        case .network: return "That didn't go through. Check your connection and try again."
        case .server: return "Something's up on our end. Give it a minute."
        case .wrongCode: return "That code's not right. Have another look."
        case .tooManyTries: return "Too many goes. Wait a couple of minutes and try again."
        case .codeNotSent: return "We couldn't text that number. Check it, or use Apple."
        case .outsideTravelArea: return "That's outside where she travels. Nothing's been charged. Pick another address, or someone closer."
        case .servicesChanged: return "Her prices changed while you were booking. Nothing's been charged. Go back and pick again."
        case .ownBooking: return "That's your own profile. Nothing's been charged. Book someone else."
        case .alreadyMoved: return "That booking's already moved on. Pull down to see where it's up to."
        case .cantReschedule: return "The time didn't change. Your hold's the same as before. Message her to sort a new one."
        case .liveBooking: return "You've still got a booking that isn't finished. Nothing's been deleted. Once it's paid or cancelled, try again."
        case .payFailed: return "That didn't go through. Your card hasn't been charged. Try again in a minute."
        }
    }
}
