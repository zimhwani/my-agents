import Foundation
import SwiftUI
import Observation
import CoreLocation

/// Which side of the app you're on.
enum AppMode: String { case client, pro }

/// Where you are in onboarding.
enum SessionStage: String { case welcome, signedIn, ready }

/// A booking made on the server but not paid for yet, kept so "Try again" pays for the same one
/// instead of asking for the slot twice.
struct PendingCheckout {
    var key: String
    var booking: Booking

    static func key(for draft: BookingDraft) -> String {
        let start = draft.start.map { String(Int($0.timeIntervalSince1970)) } ?? ""
        let services = draft.services.map(\.id).joined(separator: ",")
        let address = draft.address.map { "\($0.id)|\($0.instructions)" } ?? ""
        return [draft.pro.id, start, services, address, draft.notes].joined(separator: "#")
    }
}

/// The one shared object. Views read from it and call its methods; it talks to the services.
@Observable
final class AppState {
    let data: DataService
    let payments: PaymentService
    let location: LocationService
    /// True on the real backend, false on the sample data.
    let isLive: Bool

    var stage: SessionStage = .welcome
    var mode: AppMode = .client
    /// True while a saved session is picked up at launch, so the welcome screen doesn't flash.
    var isRestoring = false

    var client: Client? = nil
    var proSelf: Pro? = nil

    var pros: [Pro] = []
    var bookings: [Booking] = []
    var proBookings: [Booking] = []
    var threads: [MessageThread] = []
    var payouts: [Payout] = []

    /// Pros met through bookings, threads and favourites who aren't in the nearby list.
    var knownPros: [String: Pro] = [:]
    /// Full profiles (services, work, hours, reviews), loaded when one's opened.
    var proDetails: [String: Pro] = [:]
    /// First names of the clients who've booked you, for the pro side.
    var clientNames: [String: String] = [:]
    var blockedIDs: Set<String> = []

    var isLoadingPros = false
    var lastError: String? = nil
    /// A short line shown in a toast at the bottom of the screen, then cleared.
    var toast: String? = nil

    private var pendingCheckout: PendingCheckout? = nil

    /// Set when the client taps a pro from anywhere; the home tab pushes it.
    var selectedTab: ClientTab = .home
    var selectedProTab: ProTab = .today
    /// Screens that want the tab bar out of the way (a pro's profile, a chat). A count, not a flag,
    /// so a chat pushed on top of a profile can't bring the bar back when either one leaves.
    private(set) var tabBarHiders = 0
    var hidesTabBar: Bool { tabBarHiders > 0 }
    func hideTabBar() { tabBarHiders += 1 }
    func showTabBar() { tabBarHiders = max(0, tabBarHiders - 1) }

    init(data: DataService = MockDataService(), payments: PaymentService = MockPaymentService(), location: LocationService = LocationService()) {
        self.data = data
        self.payments = payments
        self.location = location
        let live = !(data is MockDataService)
        self.isLive = live
        self.isRestoring = live
    }

    /// The real backend when `HairDone.xcconfig` has the Supabase URL and key; the sample data otherwise.
    /// Stripe's sheet takes payments when there's a Stripe key and the package is in the build.
    static func configured() -> AppState {
        guard AppConfig.hasBackend, let url = AppConfig.supabaseURL else { return AppState() }
        let api = SupabaseAPI(baseURL: url, apiKey: AppConfig.supabaseKey)
        let data = SupabaseDataService(api: api)
        #if canImport(StripePaymentSheet)
        if !AppConfig.stripeKey.isEmpty {
            let stripe = StripePaymentService(publishableKey: AppConfig.stripeKey, merchantID: AppConfig.merchantID, api: api)
            return AppState(data: data, payments: stripe)
        }
        #endif
        return AppState(data: data, payments: MockPaymentService())
    }

    var userID: String { mode == .pro ? (proSelf?.id ?? "") : (client?.id ?? "") }
    var firstName: String { client?.firstName ?? "" }

    /// Shows what went wrong in a toast and keeps it for anyone who wants to show it inline.
    private func fail(_ error: Error) {
        let line = error.localizedDescription
        lastError = line
        show(line)
    }

    // MARK: Session

    /// Picks up a saved session at launch. Straight to Home if she's finished onboarding before.
    func restoreSession() async {
        defer { isRestoring = false }
        guard let restored = await data.currentClient() else { return }
        client = restored
        proSelf = await data.currentPro()
        stage = restored.firstName.isEmpty ? .signedIn : .ready
    }

    /// Texts a code. False (with `lastError` set) if it didn't go.
    @discardableResult
    func sendCode(to phone: String) async -> Bool {
        do {
            try await data.sendCode(phone: phone)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func verifyCode(_ code: String, phone: String) async {
        do {
            client = try await data.verifyCode(phone: phone, code: code)
            proSelf = await data.currentPro()
            lastError = nil
            stage = .signedIn
        } catch { lastError = error.localizedDescription }
    }

    func signInWithApple(_ credential: AppleCredential) async {
        do {
            client = try await data.signInWithApple(credential)
            proSelf = await data.currentPro()
            lastError = nil
            stage = .signedIn
        } catch { lastError = error.localizedDescription }
    }

    func finishOnboarding() {
        stage = .ready
        let named = client
        Task {
            // Saves the name from onboarding. On the real backend this makes her profile the first time.
            if let named { try? await self.data.updateClient(named) }
            await self.refreshAll()
        }
    }

    func signOut() {
        let data = self.data
        Task { await data.signOut() }
        stage = .welcome
        mode = .client
        client = nil
        if isLive { proSelf = nil }
        bookings = []; proBookings = []; threads = []; pros = []; payouts = []
        knownPros = [:]; proDetails = [:]; clientNames = [:]; blockedIDs = []
        pendingCheckout = nil
    }

    /// App Store rule: an account can be deleted from the app. False (with `lastError`) if it wasn't.
    func deleteAccount() async -> Bool {
        do {
            try await data.deleteAccount()
            signOut()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func switchMode(_ new: AppMode) {
        Haptics.medium()
        withAnimation(Motion.spring) { mode = new }
        Task { await self.refreshAll() }
    }

    // MARK: Loading

    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadPros() }
            group.addTask { await self.loadBookings(people: false) }
            group.addTask { await self.loadThreads(people: false) }
            group.addTask { await self.loadProSide(people: false) }
        }
        await loadPeople()
    }

    func loadPros(category: Category? = nil) async {
        isLoadingPros = true
        defer { isLoadingPros = false }
        do {
            if isLive && client != nil { blockedIDs = (try? await data.blockedIDs()) ?? blockedIDs }
            let blocked = blockedIDs
            pros = try await data.pros(near: location.coordinate, category: category).filter { !blocked.contains($0.id) }
        } catch { lastError = error.localizedDescription }
    }

    func loadBookings(people: Bool = true) async {
        guard let client else { return }
        do { bookings = try await data.bookings(clientID: client.id) } catch { lastError = error.localizedDescription }
        if people { await loadPeople() }
    }

    func loadThreads(people: Bool = true) async {
        let me = userID
        let side = mode
        do {
            let all = try await data.threads(userID: me)
            threads = all.filter { side == .pro ? $0.proID == me : $0.clientID == me }
        } catch { lastError = error.localizedDescription }
        if people { await loadPeople() }
    }

    func loadProSide(people: Bool = true) async {
        guard let proSelf else { return }
        do {
            proBookings = try await data.bookings(proID: proSelf.id)
            payouts = try await data.payouts(proID: proSelf.id)
        } catch { lastError = error.localizedDescription }
        if people { await loadPeople() }
    }

    /// Fills in the pros and clients the lists mention but the nearby list doesn't have.
    func loadPeople() async {
        guard isLive else { return }
        var proIDs = Set(bookings.map(\.proID))
        proIDs.formUnion(threads.map(\.proID))
        proIDs.formUnion(client?.favouriteProIDs ?? [])
        proIDs.subtract(pros.map(\.id))
        proIDs.subtract(knownPros.keys)
        if let own = proSelf?.id { proIDs.remove(own) }
        proIDs.remove("")
        if !proIDs.isEmpty {
            let found = (try? await data.proCards(ids: Array(proIDs))) ?? []
            for p in found { knownPros[p.id] = p }
        }

        var clientIDs = Set(proBookings.map(\.clientID))
        clientIDs.formUnion(threads.map(\.clientID))
        if let own = client?.id { clientIDs.remove(own) }
        clientIDs.subtract(clientNames.keys)
        clientIDs.remove("")
        if !clientIDs.isEmpty {
            let names = (try? await data.clientNames(ids: Array(clientIDs))) ?? [:]
            clientNames.merge(names) { _, new in new }
        }
    }

    /// Her whole profile, for when it's opened from a list that only had the card.
    func loadProDetail(_ id: String) async {
        guard let full = try? await data.pro(id: id) else { return }
        proDetails[id] = full
    }

    /// Back from Stripe's payout setup. Stripe tells the server a moment later, so look a few times.
    func payoutsReturned() async {
        for _ in 0..<3 {
            if let fresh = await data.currentPro() {
                proSelf = fresh
                if fresh.payoutsConnected {
                    show("Payouts on. Daily, to your bank.")
                    return
                }
            }
            try? await Task.sleep(for: .seconds(3))
        }
    }

    // MARK: Lookups

    func pro(_ id: String) -> Pro? {
        if let p = proDetails[id] { return p }
        if let p = pros.first(where: { $0.id == id }) { return p }
        if proSelf?.id == id { return proSelf }
        if let p = knownPros[id] { return p }
        return isLive ? nil : MockData.pros.first { $0.id == id }
    }

    func clientName(_ id: String) -> String {
        if id == client?.id { return client?.firstName ?? "You" }
        if let name = clientNames[id], !name.isEmpty { return name }
        return isLive ? "Client" : (MockData.clientNames[id] ?? "Client")
    }

    func isFavourite(_ pro: Pro) -> Bool { client?.favouriteProIDs.contains(pro.id) ?? false }

    func toggleFavourite(_ pro: Pro) {
        guard var c = client else { return }
        if c.favouriteProIDs.contains(pro.id) { c.favouriteProIDs.remove(pro.id) } else { c.favouriteProIDs.insert(pro.id) }
        client = c
        if knownPros[pro.id] == nil && !pros.contains(where: { $0.id == pro.id }) { knownPros[pro.id] = pro }
        Task { try? await self.data.updateClient(c) }
    }

    var favouritePros: [Pro] { (client?.favouriteProIDs ?? []).compactMap { pro($0) } }

    var upcomingBookings: [Booking] { bookings.filter { $0.status.isUpcoming }.sorted { $0.start < $1.start } }
    var pastBookings: [Booking] { bookings.filter { !$0.status.isUpcoming }.sorted { $0.start > $1.start } }
    var nextBooking: Booking? { upcomingBookings.first }
    /// Past bookings you haven't rated yet.
    var awaitingReview: [Booking] { pastBookings.filter { $0.status.isFinished && $0.review == nil } }

    var unreadCount: Int {
        threads.reduce(0) { $0 + (mode == .pro ? $1.unreadForPro : $1.unreadForClient) }
    }

    // MARK: Booking actions

    /// Makes the booking on the server, then takes payment for it. If payment doesn't finish, nothing's
    /// charged: the sample data drops the booking, the real server lets it lapse, and "Try again" pays
    /// for the same one.
    @discardableResult
    func book(_ draft: BookingDraft) async throws -> Booking {
        guard let method = draft.paymentMethod else { throw PaymentError.cancelled }
        let key = PendingCheckout.key(for: draft)
        let created: Booking
        if let pending = pendingCheckout, pending.key == key {
            created = pending.booking
        } else {
            pendingCheckout = nil
            created = try await data.createBooking(draft)
        }
        do {
            try await payments.checkout(booking: created, method: method)
        } catch {
            if isLive {
                pendingCheckout = PendingCheckout(key: key, booking: created)
            } else {
                await data.abandonBooking(id: created.id)
            }
            throw error
        }
        pendingCheckout = nil
        let booking = (try? await data.booking(id: created.id)) ?? created
        // The server keeps the card Stripe just took; pick it up for next time.
        if isLive, let fresh = await data.currentClient() { client = fresh }
        bookings.removeAll { $0.id == booking.id }
        bookings.insert(booking, at: 0)
        if knownPros[draft.pro.id] == nil && !pros.contains(where: { $0.id == draft.pro.id }) { knownPros[draft.pro.id] = draft.pro }
        await loadThreads()
        Haptics.success()
        return booking
    }

    @discardableResult
    func update(_ booking: Booking, to status: BookingStatus, reason: String? = nil) async -> Booking? {
        do {
            let updated = try await data.updateStatus(bookingID: booking.id, to: status, reason: reason)
            replace(updated)
            // The real server charges 12 hours after done by itself; the sample data pretends to.
            if status == .done && !isLive { scheduleMockCapture(for: updated) }
            // The server writes a line in the thread on every move.
            if isLive { await loadThreads() }
            return updated
        } catch { fail(error); return nil }
    }

    /// Sample data only: stands in for the 12-hour auto-capture, a few seconds after done.
    private func scheduleMockCapture(for booking: Booking) {
        Task {
            try? await Task.sleep(for: .seconds(6))
            guard let current = self.bookings.first(where: { $0.id == booking.id }) ?? self.proBookings.first(where: { $0.id == booking.id }),
                  current.status == .done else { return }
            _ = await self.update(current, to: .paid)
        }
    }

    func reschedule(_ booking: Booking, to start: Date) async {
        lastError = nil
        do { replace(try await data.reschedule(bookingID: booking.id, to: start)) } catch { lastError = error.localizedDescription }
    }

    /// Leaves the review. On a done booking that isn't paid yet, this is also "Pay": the charge and any tip go through first.
    @discardableResult
    func review(_ booking: Booking, rating: Int, text: String, tipCents: Int) async -> Bool {
        do {
            replace(try await data.submitReview(bookingID: booking.id, rating: rating, text: text, tipCents: tipCents))
            Haptics.success()
            await loadPros()
            if isLive { await loadProDetail(booking.proID) }
            return true
        } catch {
            fail(error)
            return false
        }
    }

    /// "Something wrong?" on a done booking. Holds off the charge while a person looks.
    @discardableResult
    func flag(_ booking: Booking, detail: String) async -> Bool {
        do {
            replace(try await data.flagBooking(bookingID: booking.id, detail: detail))
            return true
        } catch {
            fail(error)
            return false
        }
    }

    private func replace(_ b: Booking) {
        if let i = bookings.firstIndex(where: { $0.id == b.id }) { bookings[i] = b }
        if let i = proBookings.firstIndex(where: { $0.id == b.id }) { proBookings[i] = b }
    }

    // MARK: Messaging

    func send(_ text: String, in thread: MessageThread) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let updated = try await data.send(text: trimmed, threadID: thread.id, senderID: userID)
            if let i = threads.firstIndex(where: { $0.id == thread.id }) { threads[i] = updated }
        } catch { fail(error) }
    }

    /// Picks up new messages in an open thread.
    func refreshThread(_ id: String) async {
        guard let fresh = try? await data.thread(id: id) else { return }
        if let i = threads.firstIndex(where: { $0.id == id }) {
            // Keep it read on this side while it's open.
            var updated = fresh
            if mode == .pro { updated.unreadForPro = 0 } else { updated.unreadForClient = 0 }
            if updated.messages.count != threads[i].messages.count || updated.last?.id != threads[i].last?.id {
                threads[i] = updated
            }
        }
    }

    func markRead(_ thread: MessageThread) {
        guard let i = threads.firstIndex(where: { $0.id == thread.id }) else { return }
        let asPro = mode == .pro
        let unread = asPro ? threads[i].unreadForPro : threads[i].unreadForClient
        if asPro { threads[i].unreadForPro = 0 } else { threads[i].unreadForClient = 0 }
        guard unread > 0 || isLive else { return }
        let data = self.data
        Task { await data.markRead(threadID: thread.id, asPro: asPro) }
    }

    func thread(for booking: Booking) -> MessageThread? { threads.first { $0.bookingID == booking.id } }

    // MARK: Safety

    /// Blocks her: she's gone from your lists straight away, and the server stops showing you to each other.
    @discardableResult
    func block(_ userID: String) async -> Bool {
        do {
            try await data.block(userID: userID)
            blockedIDs.insert(userID)
            pros.removeAll { $0.id == userID }
            return true
        } catch {
            fail(error)
            return false
        }
    }

    @discardableResult
    func report(_ userID: String, bookingID: String? = nil, reason: String, detail: String) async -> Bool {
        do {
            try await data.report(userID: userID, bookingID: bookingID, reason: reason, detail: detail)
            return true
        } catch {
            fail(error)
            return false
        }
    }

    // MARK: Pro side

    func saveProSelf(_ pro: Pro) async {
        proSelf = pro
        do { proSelf = try await data.updatePro(pro) } catch { fail(error) }
    }

    func show(_ message: String) {
        withAnimation(Motion.spring) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            withAnimation(Motion.gentle) { if self.toast == message { self.toast = nil } }
        }
    }
}

enum ClientTab: String, CaseIterable { case home, bookings, inbox, you }
enum ProTab: String, CaseIterable { case today, calendar, inbox, work, earnings }
