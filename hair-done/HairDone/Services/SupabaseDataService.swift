import Foundation
import CoreLocation

/// The real backend. Schema and edge functions are in `supabase/`. Wire this up with the
/// official `supabase-swift` package; until then every call throws so nothing silently
/// pretends to work. `AppState` uses `MockDataService` by default.
final class SupabaseDataService: DataService {
    let projectURL: URL
    let anonKey: String

    init(projectURL: URL, anonKey: String) {
        self.projectURL = projectURL
        self.anonKey = anonKey
    }

    private func notWired<T>() throws -> T { throw DataError.network }

    func signIn(phone: String) async throws -> Client { try notWired() }
    func signInWithApple() async throws -> Client { try notWired() }
    func currentClient() async -> Client? { nil }
    func currentPro() async -> Pro? { nil }
    func updateClient(_ client: Client) async throws { try notWired() }
    func updatePro(_ pro: Pro) async throws { try notWired() }
    func pros(near coordinate: CLLocationCoordinate2D, category: Category?) async throws -> [Pro] { try notWired() }
    func pro(id: String) async throws -> Pro? { try notWired() }
    func slots(for pro: Pro, on day: Date, minutes: Int) async throws -> [TimeSlot] { try notWired() }
    func bookings(clientID: String) async throws -> [Booking] { try notWired() }
    func bookings(proID: String) async throws -> [Booking] { try notWired() }
    func createBooking(_ draft: BookingDraft) async throws -> Booking { try notWired() }
    func updateStatus(bookingID: String, to status: BookingStatus, reason: String?) async throws -> Booking { try notWired() }
    func reschedule(bookingID: String, to start: Date) async throws -> Booking { try notWired() }
    func submitReview(bookingID: String, rating: Int, text: String, tipCents: Int) async throws -> Booking { try notWired() }
    func threads(userID: String) async throws -> [MessageThread] { try notWired() }
    func send(text: String, threadID: String, senderID: String) async throws -> MessageThread { try notWired() }
    func payouts(proID: String) async throws -> [Payout] { try notWired() }
}
