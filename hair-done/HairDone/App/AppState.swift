import Foundation
import SwiftUI
import Observation
import CoreLocation

/// Which side of the app you're on.
enum AppMode: String { case client, pro }

/// Where you are in onboarding.
enum SessionStage: String { case welcome, signedIn, ready }

/// The one shared object. Views read from it and call its methods; it talks to the services.
@Observable
final class AppState {
    let data: DataService
    let payments: PaymentService
    let location: LocationService

    var stage: SessionStage = .welcome
    var mode: AppMode = .client

    var client: Client? = nil
    var proSelf: Pro? = nil

    var pros: [Pro] = []
    var bookings: [Booking] = []
    var proBookings: [Booking] = []
    var threads: [MessageThread] = []
    var payouts: [Payout] = []

    var isLoadingPros = false
    var lastError: String? = nil
    /// A short line shown in a toast at the bottom of the screen, then cleared.
    var toast: String? = nil

    /// Set when the client taps a pro from anywhere; the home tab pushes it.
    var selectedTab: ClientTab = .home
    var selectedProTab: ProTab = .today
    /// Screens with their own bottom bar (a pro's profile) hide the custom tab bar while shown.
    var hidesTabBar = false

    init(data: DataService = MockDataService(), payments: PaymentService = MockPaymentService(), location: LocationService = LocationService()) {
        self.data = data
        self.payments = payments
        self.location = location
    }

    var userID: String { mode == .pro ? (proSelf?.id ?? "") : (client?.id ?? "") }
    var firstName: String { client?.firstName ?? "" }

    // MARK: Session

    func signIn(phone: String) async {
        do {
            client = try await data.signIn(phone: phone)
            proSelf = await data.currentPro()
            stage = .signedIn
        } catch { lastError = error.localizedDescription }
    }

    func signInWithApple() async {
        do {
            client = try await data.signInWithApple()
            proSelf = await data.currentPro()
            stage = .signedIn
        } catch { lastError = error.localizedDescription }
    }

    func finishOnboarding() {
        stage = .ready
        Task { await self.refreshAll() }
    }

    func signOut() {
        stage = .welcome
        mode = .client
        client = nil
        bookings = []; proBookings = []; threads = []; pros = []
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
            group.addTask { await self.loadBookings() }
            group.addTask { await self.loadThreads() }
            group.addTask { await self.loadProSide() }
        }
    }

    func loadPros(category: Category? = nil) async {
        isLoadingPros = true
        defer { isLoadingPros = false }
        do { pros = try await data.pros(near: location.coordinate, category: category) } catch { lastError = error.localizedDescription }
    }

    func loadBookings() async {
        guard let client else { return }
        do { bookings = try await data.bookings(clientID: client.id) } catch { lastError = error.localizedDescription }
    }

    func loadThreads() async {
        do { threads = try await data.threads(userID: userID) } catch { lastError = error.localizedDescription }
    }

    func loadProSide() async {
        guard let proSelf else { return }
        do {
            proBookings = try await data.bookings(proID: proSelf.id)
            payouts = try await data.payouts(proID: proSelf.id)
        } catch { lastError = error.localizedDescription }
    }

    // MARK: Lookups

    func pro(_ id: String) -> Pro? {
        if let p = pros.first(where: { $0.id == id }) { return p }
        if proSelf?.id == id { return proSelf }
        return MockData.pros.first { $0.id == id }
    }

    func clientName(_ id: String) -> String {
        if id == client?.id { return client?.firstName ?? "You" }
        return MockData.clientNames[id] ?? "Client"
    }

    func isFavourite(_ pro: Pro) -> Bool { client?.favouriteProIDs.contains(pro.id) ?? false }

    func toggleFavourite(_ pro: Pro) {
        guard var c = client else { return }
        if c.favouriteProIDs.contains(pro.id) { c.favouriteProIDs.remove(pro.id) } else { c.favouriteProIDs.insert(pro.id) }
        client = c
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

    @discardableResult
    func book(_ draft: BookingDraft) async throws -> Booking {
        guard let method = draft.paymentMethod else { throw PaymentError.cancelled }
        let price = draft.price
        let reference = MockDataService.reference()
        _ = try await payments.authorise(amountCents: price.clientTotalCents, method: method, bookingReference: reference)
        let booking = try await data.createBooking(draft)
        bookings.insert(booking, at: 0)
        await loadThreads()
        Haptics.success()
        return booking
    }

    @discardableResult
    func update(_ booking: Booking, to status: BookingStatus, reason: String? = nil) async -> Booking? {
        do {
            let updated = try await data.updateStatus(bookingID: booking.id, to: status, reason: reason)
            replace(updated)
            if status == .done { scheduleMockCapture(for: updated) }
            return updated
        } catch { lastError = error.localizedDescription; return nil }
    }

    /// Stands in for the 12-hour auto-capture: in the mock, a done booking is charged a few seconds later.
    private func scheduleMockCapture(for booking: Booking) {
        Task {
            try? await Task.sleep(for: .seconds(6))
            guard let current = self.bookings.first(where: { $0.id == booking.id }) ?? self.proBookings.first(where: { $0.id == booking.id }),
                  current.status == .done else { return }
            _ = await self.update(current, to: .paid)
        }
    }

    func reschedule(_ booking: Booking, to start: Date) async {
        do { replace(try await data.reschedule(bookingID: booking.id, to: start)) } catch { lastError = error.localizedDescription }
    }

    func review(_ booking: Booking, rating: Int, text: String, tipCents: Int) async {
        do {
            replace(try await data.submitReview(bookingID: booking.id, rating: rating, text: text, tipCents: tipCents))
            Haptics.success()
            await loadPros()
        } catch { lastError = error.localizedDescription }
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
        } catch { lastError = error.localizedDescription }
    }

    func markRead(_ thread: MessageThread) {
        guard let i = threads.firstIndex(where: { $0.id == thread.id }) else { return }
        if mode == .pro { threads[i].unreadForPro = 0 } else { threads[i].unreadForClient = 0 }
    }

    func thread(for booking: Booking) -> MessageThread? { threads.first { $0.bookingID == booking.id } }

    // MARK: Pro side

    func saveProSelf(_ pro: Pro) async {
        proSelf = pro
        do { try await data.updatePro(pro) } catch { lastError = error.localizedDescription }
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
