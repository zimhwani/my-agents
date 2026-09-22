import Foundation
import CoreLocation

/// In-memory backend. Deterministic seed, small artificial delays so loading states show.
final class MockDataService: DataService {
    private var client: Client? = MockData.client
    private var proSelf: Pro = MockData.proSelf
    private var pros: [Pro] = MockData.pros
    private var bookings: [Booking] = MockData.bookings() + MockData.proBookings().filter { $0.id != "pb_3" }
    private var threads: [MessageThread] = MockData.threads()
    private var payouts: [Payout] = MockData.payouts()
    private var signedIn = false

    /// Set to 0 in previews/tests.
    var latencyMs: Int = 350

    private func pause(_ factor: Double = 1) async {
        let ms = Int(Double(latencyMs) * factor)
        if ms > 0 { try? await Task.sleep(for: .milliseconds(ms)) }
    }

    // MARK: Session

    func signIn(phone: String) async throws -> Client {
        await pause(2)
        signedIn = true
        return client ?? MockData.client
    }
    func signInWithApple() async throws -> Client {
        await pause(1.5)
        signedIn = true
        return client ?? MockData.client
    }
    func currentClient() async -> Client? { client }
    func currentPro() async -> Pro? { proSelf }
    func updateClient(_ client: Client) async throws { await pause(0.5); self.client = client }
    func updatePro(_ pro: Pro) async throws {
        await pause(0.5)
        proSelf = pro
        if let i = pros.firstIndex(where: { $0.id == pro.id }) { pros[i] = pro }
    }

    // MARK: Discovery

    func pros(near coordinate: CLLocationCoordinate2D, category: Category?) async throws -> [Pro] {
        await pause()
        var list = pros.filter { $0.isActive }
        if let category { list = list.filter { $0.specialties.contains(category) } }
        return list.sorted { $0.distanceKm(from: coordinate) < $1.distanceKm(from: coordinate) }
    }

    func pro(id: String) async throws -> Pro? { await pause(0.3); return pros.first { $0.id == id } }

    func slots(for pro: Pro, on day: Date, minutes: Int) async throws -> [TimeSlot] {
        await pause(0.6)
        let ranges = pro.availability.ranges(on: day)
        guard !ranges.isEmpty else { return [] }
        let taken = bookings.filter { $0.proID == pro.id && $0.status.isUpcoming && Calendar.current.isDate($0.start, inSameDayAs: day) }
        var slots: [TimeSlot] = []
        let step = pro.availability.stepMinutes
        let buffer = pro.availability.bufferMinutes
        for r in ranges {
            var m = r.startMinutes
            while m + minutes <= r.endMinutes {
                let start = day.startOfDay.adding(minutes: m)
                let end = start.adding(minutes: minutes)
                var available = true
                var reason: String? = nil
                if start < Date().adding(minutes: 90) {
                    available = false; reason = "Too soon, she needs 90 minutes' notice"
                } else if let clash = taken.first(where: { $0.start.adding(minutes: -buffer) < end && $0.end.adding(minutes: buffer) > start }) {
                    available = false
                    reason = clash.start <= start && clash.end >= end ? "She's booked" : "Too close to another job"
                }
                slots.append(TimeSlot(start: start, isAvailable: available, reason: reason))
                m += step
            }
        }
        return slots
    }

    // MARK: Bookings

    func bookings(clientID: String) async throws -> [Booking] {
        await pause()
        return bookings.filter { $0.clientID == clientID }.sorted { $0.start > $1.start }
    }

    func bookings(proID: String) async throws -> [Booking] {
        await pause()
        return bookings.filter { $0.proID == proID }.sorted { $0.start < $1.start }
    }

    func createBooking(_ draft: BookingDraft) async throws -> Booking {
        await pause(2)
        guard let start = draft.start, let address = draft.address, let clientID = client?.id else { throw DataError.notSignedIn }
        let taken = bookings.contains { $0.proID == draft.pro.id && $0.status.isUpcoming && $0.start == start }
        if taken { throw DataError.slotTaken }
        let id = "bk_\(UUID().uuidString.prefix(6))"
        let status: BookingStatus = draft.pro.instantBook ? .confirmed : .requested
        let now = Date()
        var events = [StatusEvent(id: "\(id)_e0", status: .requested, at: now)]
        if status == .confirmed { events.append(StatusEvent(id: "\(id)_e1", status: .confirmed, at: now)) }
        let booking = Booking(
            id: id, proID: draft.pro.id, clientID: clientID, services: draft.services, start: start, address: address,
            notes: draft.notes, inspoSeeds: draft.inspoSeeds, status: status, price: draft.price, createdAt: now, events: events,
            paymentMethodID: draft.paymentMethod?.id, reference: Self.reference()
        )
        bookings.append(booking)
        let intro = status == .confirmed
            ? "Booking confirmed for \(start.friendlyDayTime)."
            : "You asked \(draft.pro.firstName) for \(start.friendlyDayTime)."
        threads.append(MessageThread(id: "th_\(id)", bookingID: id, proID: draft.pro.id, clientID: clientID, messages: [
            Message(id: "m_\(id)_0", threadID: "th_\(id)", senderID: "system", text: intro, sentAt: now, isSystem: true)
        ]))
        return booking
    }

    func updateStatus(bookingID: String, to status: BookingStatus, reason: String?) async throws -> Booking {
        await pause(0.8)
        guard let i = bookings.firstIndex(where: { $0.id == bookingID }) else { throw DataError.notFound }
        bookings[i].status = status
        bookings[i].declineReason = reason
        bookings[i].events.append(StatusEvent(id: "\(bookingID)_e\(bookings[i].events.count)", status: status, at: Date()))
        if status == .cancelledByClient {
            let charge = bookings[i].cancellationChargeCents
            bookings[i].price.servicesCents = charge
            bookings[i].price.travelFeeCents = 0
            bookings[i].price.bookingFeeCents = 0
        }
        return bookings[i]
    }

    func reschedule(bookingID: String, to start: Date) async throws -> Booking {
        await pause()
        guard let i = bookings.firstIndex(where: { $0.id == bookingID }) else { throw DataError.notFound }
        bookings[i].start = start
        if bookings[i].status == .confirmed && !(pros.first { $0.id == bookings[i].proID }?.instantBook ?? true) {
            bookings[i].status = .requested
        }
        return bookings[i]
    }

    func submitReview(bookingID: String, rating: Int, text: String, tipCents: Int) async throws -> Booking {
        await pause()
        guard let i = bookings.firstIndex(where: { $0.id == bookingID }) else { throw DataError.notFound }
        let b = bookings[i]
        let review = Review(id: "rv_\(bookingID)", clientFirstName: client?.firstName ?? "You", rating: rating, text: text, date: Date(), serviceName: b.services.first?.name ?? "")
        bookings[i].review = review
        bookings[i].price.tipCents = tipCents
        if let p = pros.firstIndex(where: { $0.id == b.proID }) {
            pros[p].reviews.insert(review, at: 0)
            let total = pros[p].rating * Double(pros[p].reviewCount) + Double(rating)
            pros[p].reviewCount += 1
            pros[p].rating = (total / Double(pros[p].reviewCount) * 10).rounded() / 10
        }
        return bookings[i]
    }

    // MARK: Messaging

    func threads(userID: String) async throws -> [MessageThread] {
        await pause(0.5)
        return threads.filter { $0.clientID == userID || $0.proID == userID }
            .sorted { ($0.last?.sentAt ?? .distantPast) > ($1.last?.sentAt ?? .distantPast) }
    }

    func send(text: String, threadID: String, senderID: String) async throws -> MessageThread {
        await pause(0.3)
        guard let i = threads.firstIndex(where: { $0.id == threadID }) else { throw DataError.notFound }
        threads[i].messages.append(Message(id: UUID().uuidString, threadID: threadID, senderID: senderID, text: text, sentAt: Date()))
        if senderID == threads[i].clientID { threads[i].unreadForPro += 1; threads[i].unreadForClient = 0 } else { threads[i].unreadForClient += 1; threads[i].unreadForPro = 0 }
        return threads[i]
    }

    // MARK: Pro

    func payouts(proID: String) async throws -> [Payout] { await pause(); return payouts }

    static func reference() -> String {
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return "HD-" + String((0..<4).map { _ in letters.randomElement()! })
    }
}
