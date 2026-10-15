import Foundation
import CoreLocation

/// Everything the app reads or writes goes through here. `SupabaseDataService` is the real backend
/// in `supabase/`; `MockDataService` is the in-memory stand-in for previews and for running without keys.
protocol DataService: AnyObject {
    // Session
    /// Texts a six-digit code to an Australian mobile ("0412 345 678").
    func sendCode(phone: String) async throws
    func verifyCode(phone: String, code: String) async throws -> Client
    /// Emails a six-digit code. The account is made the first time.
    func sendEmailCode(email: String) async throws
    func verifyEmailCode(email: String, code: String) async throws -> Client
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

    // Push
    /// Ties this phone's APNs token (hex) to the signed-in account. `environment` is "sandbox" or "production".
    func registerDevice(token: String, environment: String) async throws
    /// Takes the token off the account. Called before signing out, while there's still a session.
    func unregisterDevice(token: String) async throws

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
    /// If the payment goes through and the review doesn't, throws `DataError.paidReviewNotSaved`.
    func submitReview(bookingID: String, rating: Int, text: String, tipCents: Int) async throws -> Booking
    /// Pays for a done booking, with the tip, and nothing else. The review is its own step afterwards.
    func pay(bookingID: String, tipCents: Int) async throws -> Booking
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
    /// Asks Stripe (through the server) whether payouts are on yet. The server records the answer too.
    func payoutStatus() async throws -> Bool

    // Switches
    /// Server-side switches (`app_flags`), read before sign-in. Empty if they couldn't be loaded.
    func appFlags() async -> [String: Bool]
    func closeProProfile() async throws
    func reopenProProfile() async throws

    // Photos and ID
    /// Her work photo, uploaded. The public URL goes in `WorkItem.imageURL`, then `updatePro` saves it.
    func uploadWorkPhoto(_ jpeg: Data) async throws -> URL
    /// Her profile photo, uploaded and saved on her profile (both sides use it).
    func uploadAvatar(_ jpeg: Data) async throws -> URL
    /// Photo ID or a selfie, into her private folder. Sending one again replaces it.
    func uploadIDDocument(_ jpeg: Data, kind: IDDocumentKind) async throws
    /// Asks for a person to check her ID. Throws `DataError.idDocsMissing` until both photos are in.
    func submitIDCheck() async throws

    // Discovery, server side
    /// Pro id → her first free start today, for pros who can come to you.
    func whosFree(near coordinate: CLLocationCoordinate2D, category: Category?) async throws -> [String: Date]
    /// Every bookable pro whose name, suburb, headline, services or specialty match. Two characters or more.
    func searchPros(_ query: String, near coordinate: CLLocationCoordinate2D) async throws -> [Pro]

    // Phone
    /// Texts a code to the new number. Nothing changes until it's verified.
    func changePhone(to phone: String) async throws
    func verifyPhoneChange(phone: String, code: String) async throws -> Client
}

/// What the booking flow builds up before it's confirmed.
struct BookingDraft {
    var pro: Pro
    var services: [Service] = []
    var start: Date? = nil
    var address: Address? = nil
    var notes: String = ""
    var inspoSeeds: [Int] = []
    /// JPEGs picked at the notes step. Uploaded once the booking exists; one that fails doesn't stop it.
    var inspoPhotos: [Data] = []
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
    case emailNotSent
    case codeExpired
    case outsideTravelArea
    case servicesChanged
    case ownBooking
    case alreadyMoved
    case cantReschedule
    case liveBooking
    case payFailed
    case paidReviewNotSaved
    case tooLateToMove
    case tooFarToMove
    case idDocsMissing
    case uploadFailed
    case offline

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "You're not signed in."
        case .notFound: return "We couldn't find that one."
        case .slotTaken: return "Someone just took that time. Here's what's still free."
        case .network: return "That didn't go through. Check your connection and try again."
        case .server: return "Something's up on our end. Give it a minute."
        case .wrongCode: return "That code's not right. Have another look."
        case .tooManyTries: return "Too many tries. Wait a minute and ask for a new code."
        case .codeNotSent: return "We couldn't text that number. Check it, or use Apple."
        case .emailNotSent: return "We couldn't send a code to that email. Check it, or use Apple."
        case .codeExpired: return "That code's expired. We've sent a new one."
        case .outsideTravelArea: return "That's outside where she travels. Nothing's been charged. Pick another address, or someone closer."
        case .servicesChanged: return "Her prices changed while you were booking. Nothing's been charged. Go back and pick again."
        case .ownBooking: return "That's your own profile. Nothing's been charged. Book someone else."
        case .alreadyMoved: return "That booking's already moved on. Pull down to see where it's up to."
        case .cantReschedule: return "The time didn't change. Your hold's the same as before. Message her to sort a new one."
        case .liveBooking: return "You've still got a booking that isn't finished. Nothing's been deleted. Once it's paid or cancelled, try again."
        case .payFailed: return "That didn't go through. Your card hasn't been charged. Try again in a minute."
        case .paidReviewNotSaved: return "Paid. Your review didn't save. Try again from the booking."
        case .tooLateToMove: return "It's under 24 hours away, so it can't move now. Message her, or cancel."
        case .tooFarToMove: return "That's too far out to move while your card's on hold. Pick a time in the next six days."
        case .idDocsMissing: return "Add your photo ID and a selfie first."
        case .uploadFailed: return "Didn't upload. Tap to try again."
        case .offline: return "You're offline. Try again when you're back."
        }
    }
}
