import Foundation
import CoreLocation

/// In-memory backend for previews and for running without backend keys.
/// Deterministic seed, small artificial delays so loading states show.
final class MockDataService: DataService {
    private var client: Client? = MockData.client
    private var proSelf: Pro = MockData.proSelf
    private var pros: [Pro] = MockData.pros
    private var bookings: [Booking] = MockData.bookings() + MockData.proBookings().filter { $0.id != "pb_3" }
    private var threads: [MessageThread] = MockData.threads()
    private var payouts: [Payout] = MockData.payouts()
    private var blocked: Set<String> = []
    private var signedIn = false
    /// ID photos she's added.
    private var idDocs: Set<IDDocumentKind> = []

    /// Set to 0 in previews/tests.
    var latencyMs: Int = 350

    private func pause(_ factor: Double = 1) async {
        let ms = Int(Double(latencyMs) * factor)
        if ms > 0 { try? await Task.sleep(for: .milliseconds(ms)) }
    }

    // MARK: Session

    func sendCode(phone: String) async throws { await pause(1.5) }
    func verifyCode(phone: String, code: String) async throws -> Client {
        await pause(2)
        signedIn = true
        return client ?? MockData.client
    }
    /// Any email works, and any six digits after it, the same as the phone.
    func sendEmailCode(email: String) async throws { await pause(1.5) }
    func verifyEmailCode(email: String, code: String) async throws -> Client {
        await pause(2)
        signedIn = true
        var signedInClient = client ?? MockData.client
        if signedInClient.email.isEmpty { signedInClient.email = email }
        client = signedInClient
        return signedInClient
    }
    func signInWithApple(_ credential: AppleCredential) async throws -> Client {
        await pause(1.5)
        signedIn = true
        return client ?? MockData.client
    }
    /// Signed out at launch, so the app opens on the welcome screen as it always has.
    func currentClient() async -> Client? { signedIn ? client : nil }
    func currentPro() async -> Pro? { proSelf }
    func updateClient(_ client: Client) async throws { await pause(0.5); self.client = client }
    func updatePro(_ pro: Pro) async throws -> Pro {
        await pause(0.5)
        proSelf = pro
        if let i = pros.firstIndex(where: { $0.id == pro.id }) { pros[i] = pro }
        return pro
    }
    func signOut() async { signedIn = false }
    func deleteAccount() async throws {
        await pause()
        if bookings.contains(where: { $0.clientID == client?.id && ($0.status.isUpcoming || $0.status == .done) }) {
            throw DataError.liveBooking
        }
        signedIn = false
    }

    // MARK: Push

    /// Nothing to send pushes from in the sample data.
    func registerDevice(token: String, environment: String) async throws {}
    func unregisterDevice(token: String) async throws {}

    // MARK: Discovery

    /// The pros a client can find: taking bookings, finished onboarding, not closed, not blocked.
    private var listed: [Pro] {
        pros.filter { $0.isActive && $0.isOnboarded && !$0.isClosed && !blocked.contains($0.id) }
    }

    func pros(near coordinate: CLLocationCoordinate2D, category: Category?) async throws -> [Pro] {
        await pause()
        var list = listed
        if let category { list = list.filter { $0.specialties.contains(category) } }
        return list.sorted { $0.distanceKm(from: coordinate) < $1.distanceKm(from: coordinate) }
    }

    func pro(id: String) async throws -> Pro? { await pause(0.3); return pros.first { $0.id == id } }

    func proCards(ids: [String]) async throws -> [Pro] { pros.filter { ids.contains($0.id) } }

    func clientNames(ids: [String]) async throws -> [String: String] { MockData.clientNames }

    func whosFree(near coordinate: CLLocationCoordinate2D, category: Category?) async throws -> [String: Date] {
        await pause(0.5)
        var out: [String: Date] = [:]
        for p in listed where category.map({ p.specialties.contains($0) }) ?? true {
            let shortest = p.services.map(\.minutes).min() ?? 60
            if let first = openings(for: p, on: Date(), minutes: shortest).first(where: \.isAvailable) {
                out[p.id] = first.start
            }
        }
        return out
    }

    func searchPros(_ query: String, near coordinate: CLLocationCoordinate2D) async throws -> [Pro] {
        await pause(0.5)
        let words = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard words.count >= 2 else { return [] }
        return listed.filter { p in
            var hay = [p.firstName, p.suburb, p.headline] + p.services.map(\.name)
            hay += p.specialties.flatMap { [$0.label, $0.specialtyTitle] }
            return hay.contains { $0.lowercased().contains(words) }
        }
        .sorted { $0.distanceKm(from: coordinate) < $1.distanceKm(from: coordinate) }
    }

    func slots(for pro: Pro, on day: Date, minutes: Int) async throws -> [TimeSlot] {
        await pause(0.6)
        return openings(for: pro, on: day, minutes: minutes)
    }

    /// Her start times on a day: her hours, less her notice and anything booked (with her buffer).
    private func openings(for pro: Pro, on day: Date, minutes: Int) -> [TimeSlot] {
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
                if start < Date().adding(minutes: pro.noticeMinutes) {
                    available = false; reason = Self.noticeReason(pro.noticeMinutes)
                } else if let clash = taken.first(where: { $0.start.adding(minutes: -buffer) < end && $0.end.adding(minutes: buffer) > start }) {
                    available = false
                    reason = clash.start <= start && clash.end >= end ? "They're booked" : "Too close to another job"
                }
                slots.append(TimeSlot(start: start, isAvailable: available, reason: reason))
                m += step
            }
        }
        return slots
    }

    /// "Too soon, she needs 2 hours' notice"
    private static func noticeReason(_ minutes: Int) -> String {
        if minutes >= 1440 { return "Too soon, they need a day's notice" }
        if minutes == 60 { return "Too soon, they need an hour's notice" }
        if minutes % 60 == 0 { return "Too soon, they need \(minutes / 60) hours' notice" }
        return "Too soon, they need \(minutes) minutes' notice"
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

    func booking(id: String) async throws -> Booking? { bookings.first { $0.id == id } }

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
            paymentMethodID: draft.paymentMethod?.id, reference: Self.reference(),
            inspoURLs: draft.inspoPhotos.compactMap { try? Self.saveToCaches($0) }
        )
        bookings.append(booking)
        let intro = status == .confirmed
            ? "Confirmed for \(start.friendlyDayInSentence) at \(start.clock)."
            : "You asked for \(start.friendlyDayInSentence) at \(start.clock)."
        threads.append(MessageThread(id: "th_\(id)", bookingID: id, proID: draft.pro.id, clientID: clientID, messages: [
            Message(id: "m_\(id)_0", threadID: "th_\(id)", senderID: "system", text: intro, sentAt: now, isSystem: true)
        ]))
        return booking
    }

    func abandonBooking(id: String) async {
        bookings.removeAll { $0.id == id }
        threads.removeAll { $0.bookingID == id }
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

    /// The server's rules: requested or confirmed, 24 hours out or more, and a time she's free.
    func reschedule(bookingID: String, to start: Date) async throws -> Booking {
        await pause()
        guard let i = bookings.firstIndex(where: { $0.id == bookingID }) else { throw DataError.notFound }
        let b = bookings[i]
        guard b.status == .requested || b.status == .confirmed else { throw DataError.alreadyMoved }
        guard b.hoursUntil >= Double(Fees.freeCancellationHours) else { throw DataError.tooLateToMove }
        let end = start.adding(minutes: b.minutes)
        let buffer = pros.first { $0.id == b.proID }?.availability.bufferMinutes ?? 30
        let clash = bookings.contains {
            $0.id != b.id && $0.proID == b.proID && $0.status.isUpcoming
                && $0.start.adding(minutes: -buffer) < end && $0.end.adding(minutes: buffer) > start
        }
        if clash { throw DataError.slotTaken }
        bookings[i].start = start
        if let t = threads.firstIndex(where: { $0.bookingID == bookingID }) {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_AU")
            f.dateFormat = "EEEE d MMMM"
            let line = "Moved to \(f.string(from: start)), \(start.clock)."
            threads[t].messages.append(Message(id: UUID().uuidString, threadID: threads[t].id, senderID: "system", text: line,
                                               sentAt: Date(), isSystem: true))
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

    func pay(bookingID: String, tipCents: Int) async throws -> Booking {
        await pause()
        guard let i = bookings.firstIndex(where: { $0.id == bookingID }) else { throw DataError.notFound }
        if bookings[i].status == .done {
            bookings[i].status = .paid
            bookings[i].price.tipCents = max(0, tipCents)
        }
        return bookings[i]
    }

    func receiptDetails(bookingID: String) async throws -> ReceiptDetails {
        await pause(0.3)
        guard let b = bookings.first(where: { $0.id == bookingID }) else { throw DataError.notFound }
        let abn = pros.first(where: { $0.id == b.proID })?.abn
        return ReceiptDetails(proABN: abn?.isEmpty == false ? abn : nil, card: "Visa •••• 4242",
                              paidAt: b.events.last(where: { $0.status == .paid })?.at ?? b.end, canEmail: true)
    }

    func emailReceipt(bookingID: String) async throws -> String {
        await pause(0.8)
        return "you@example.com"
    }

    func flagBooking(bookingID: String, detail: String) async throws -> Booking {
        await pause(0.5)
        guard let b = bookings.first(where: { $0.id == bookingID }) else { throw DataError.notFound }
        return b
    }

    // MARK: Messaging

    func threads(userID: String) async throws -> [MessageThread] {
        await pause(0.5)
        return threads.filter { $0.clientID == userID || $0.proID == userID }
            .sorted { ($0.last?.sentAt ?? .distantPast) > ($1.last?.sentAt ?? .distantPast) }
    }

    func thread(id: String) async throws -> MessageThread? { threads.first { $0.id == id } }

    func send(text: String, threadID: String, senderID: String) async throws -> MessageThread {
        await pause(0.3)
        guard let i = threads.firstIndex(where: { $0.id == threadID }) else { throw DataError.notFound }
        threads[i].messages.append(Message(id: UUID().uuidString, threadID: threadID, senderID: senderID, text: text, sentAt: Date()))
        if senderID == threads[i].clientID { threads[i].unreadForPro += 1; threads[i].unreadForClient = 0 } else { threads[i].unreadForClient += 1; threads[i].unreadForPro = 0 }
        return threads[i]
    }

    func markRead(threadID: String, asPro: Bool) async {
        guard let i = threads.firstIndex(where: { $0.id == threadID }) else { return }
        if asPro { threads[i].unreadForPro = 0 } else { threads[i].unreadForClient = 0 }
    }

    // MARK: Safety

    func blockedIDs() async throws -> Set<String> { blocked }
    func block(userID: String) async throws { await pause(0.3); blocked.insert(userID) }
    func report(userID: String, bookingID: String?, reason: String, detail: String) async throws { await pause(0.5) }

    // MARK: Pro

    func payouts(proID: String) async throws -> [Payout] { await pause(); return payouts }
    func payoutStatus() async throws -> Bool { await pause(0.5); return proSelf.payoutsConnected }

    func appFlags() async -> [String: Bool] { ["phone_sign_in": true] }

    func closeProProfile() async throws {
        await pause()
        let live = bookings.contains { $0.proID == proSelf.id && ($0.status.isUpcoming || $0.status == .done) }
        if live { throw DataError.liveBooking }
        proSelf.isClosed = true
        proSelf.isActive = false
        if let i = pros.firstIndex(where: { $0.id == proSelf.id }) { pros[i] = proSelf }
    }

    func reopenProProfile() async throws {
        await pause()
        proSelf.isClosed = false
        proSelf.isActive = true
        if let i = pros.firstIndex(where: { $0.id == proSelf.id }) { pros[i] = proSelf }
    }

    // MARK: Photos and ID

    /// Writes the JPEG to the caches folder, so the photo really shows. Nothing leaves the phone.
    private static func saveToCaches(_ jpeg: Data) throws -> URL {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw DataError.uploadFailed
        }
        let folder = caches.appendingPathComponent("sample-uploads", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appendingPathComponent(UUID().uuidString.lowercased() + ".jpg")
            try jpeg.write(to: file, options: .atomic)
            return file
        } catch {
            throw DataError.uploadFailed
        }
    }

    func uploadWorkPhoto(_ jpeg: Data) async throws -> URL {
        await pause(1.5)
        return try Self.saveToCaches(jpeg)
    }

    func uploadAvatar(_ jpeg: Data) async throws -> URL {
        await pause(1.2)
        let url = try Self.saveToCaches(jpeg)
        client?.avatarURL = url
        proSelf.avatarURL = url
        if let i = pros.firstIndex(where: { $0.id == proSelf.id }) { pros[i].avatarURL = url }
        return url
    }

    func uploadIDDocument(_ jpeg: Data, kind: IDDocumentKind) async throws {
        await pause(1.2)
        _ = try Self.saveToCaches(jpeg)
        idDocs.insert(kind)
    }

    func submitIDCheck() async throws {
        await pause()
        guard idDocs.count == IDDocumentKind.allCases.count else { throw DataError.idDocsMissing }
        proSelf.idSubmitted = true
    }

    // MARK: Phone

    func changePhone(to phone: String) async throws { await pause(1.5) }

    /// Any six digits, the same as signing in.
    func verifyPhoneChange(phone: String, code: String) async throws -> Client {
        await pause(1.5)
        var c = client ?? MockData.client
        c.phone = AUPhone.display(phone)
        client = c
        return c
    }

    static func reference() -> String {
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return "HD-" + String((0..<4).map { _ in letters.randomElement()! })
    }
}
