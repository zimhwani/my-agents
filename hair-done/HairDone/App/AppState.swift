import Foundation
import SwiftUI
import Observation
import CoreLocation
import Network

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

/// How leaving a review went. Paying and reviewing are separate on the server, so the money can
/// go through when the review doesn't.
enum ReviewOutcome {
    case saved
    /// Paid, but the review needs another go. The booking shows as paid and a toast says so.
    case paidOnly
    case failed(String)
}

/// Something to say about payout setup, as an alert on whichever screen is up.
enum PayoutNotice: Identifiable {
    /// The link didn't come back from the server, or iOS wouldn't open it.
    case didntOpen
    /// Back from Stripe, finished, but Stripe hasn't switched payouts on yet.
    case stillChecking
    /// Back from Stripe through `/refresh`: the link ran out before she finished.
    case linkExpired

    var id: Self { self }
}

/// The one shared object. Views read from it and call its methods; it talks to the services.
/// Main actor throughout: every load and action lands its results on the main thread, so a view
/// never sees state change underneath it from a background executor.
@MainActor
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
    /// Threads on the side she's on. The other side's are loaded with them, so a switch never shows
    /// one side's threads under the other side's labels.
    var threads: [MessageThread] = []
    var otherSideThreads: [MessageThread] = []
    var payouts: [Payout] = []

    /// Pro id → her first free start today, for Who's free. Loaded with `pros`.
    var whosFree: [String: Date] = [:]
    /// Server search across every bookable pro, not just the ones near you.
    var searchResults: [Pro] = []
    var isSearching = false
    /// The search the results are for, so a slow one can't land on top of a newer one.
    private var searchQuery = ""

    /// No network. Screens show the offline bar and hold back anything that needs the server.
    var isOffline = false
    private let pathMonitor = NWPathMonitor()

    /// True when the last load failed (not when it came back empty), so a screen can say so and offer Try again.
    var prosLoadFailed = false
    var bookingsLoadFailed = false
    var threadsLoadFailed = false
    var proSideLoadFailed = false

    /// Pros met through bookings, threads and favourites who aren't in the nearby list.
    var knownPros: [String: Pro] = [:]
    /// Full profiles (services, work, hours, reviews), loaded when one's opened.
    var proDetails: [String: Pro] = [:]
    /// First names of the clients who've booked you, for the pro side.
    var clientNames: [String: String] = [:]
    /// Client ids whose name lookup has come back, with or without a name. Until then a pro screen
    /// shows a shimmer where the name goes, not "Client".
    var clientNamesLookedUp: Set<String> = []
    var blockedIDs: Set<String> = []

    var isLoadingPros = false
    /// True while that load is going. Screens show skeletons only while there's nothing yet
    /// (see `showsBookingsSkeleton` and friends), never over what's already there.
    var isLoadingBookings = false
    var isLoadingThreads = false
    var isLoadingProSide = false
    /// True once that load has come back at least once (empty or not) since sign-in.
    var hasLoadedBookings = false
    var hasLoadedThreads = false
    var hasLoadedProSide = false
    /// True once the first `refreshAll` since sign-in has finished.
    private(set) var hasLoadedOnce = false
    /// The `refreshAll` that's going, so a second caller waits for it instead of loading everything twice.
    @ObservationIgnored private var refreshing: Task<Void, Never>? = nil
    var lastError: String? = nil
    /// The last error as one of ours, when it was, so a screen can match the case (`.liveBooking`)
    /// instead of the wording. Set alongside `lastError`.
    var lastDataError: DataError? = nil
    /// Why the last sign-in code didn't work, when it was one of ours (wrong, expired, too many tries).
    var signInFailure: DataError? = nil
    /// A short line shown in a toast at the bottom of the screen, then cleared.
    var toast: String? = nil

    private var pendingCheckout: PendingCheckout? = nil

    /// The thread on screen right now, so a push for it doesn't also show as a banner.
    var openThreadID: String? = nil
    /// A screen a notification asked for. The tab it belongs to pushes it and clears this.
    var pendingRoute: Route? = nil
    /// A tapped notification that's waiting: she wasn't signed in yet, or she was in the middle of
    /// something (see `busySurfaces`). Opened once she's free.
    private var pendingPush: PushTarget? = nil
    /// A pro link that came in before she was signed in (it launched the app, say). Opened once she is.
    private var pendingProLink: String? = nil
    /// Screens she's in the middle of (the booking flow, pro onboarding, payout setup, sheets with
    /// unsaved input). While any is up, a tapped notification waits instead of switching sides or
    /// moving things underneath her. Counted by `.holdsPushRoutes()`.
    var busySurfaces = 0
    /// She tapped "Do hair, nails or makeup? Get booked here." on Welcome: after sign-in, You opens pro onboarding.
    var wantsProOnboarding = false

    /// Shown as an alert by the payout screens, or by the root when none of them is up.
    var payoutNotice: PayoutNotice? = nil
    /// How many payout screens are showing; the root only shows `payoutNotice` when it's 0.
    var payoutSurfaces = 0

    /// Set when the client taps a pro from anywhere; the home tab pushes it.
    var selectedTab: ClientTab = .home
    var selectedProTab: ProTab = .today
    /// Screens that want the tab bar out of the way (a pro's profile, a chat). A count, not a flag,
    /// so a chat pushed on top of a profile can't bring the bar back when either one leaves.
    private(set) var tabBarHiders = 0
    var hidesTabBar: Bool { tabBarHiders > 0 }
    func hideTabBar() { tabBarHiders += 1 }
    func showTabBar() { tabBarHiders = max(0, tabBarHiders - 1) }

    /// Where each tab's stack is, kept here rather than in the tab, so switching sides and back
    /// lands her on the screen she left (the shells are rebuilt on every switch).
    var clientPaths: [ClientTab: NavigationPath] = [:]
    var proPaths: [ProTab: NavigationPath] = [:]

    /// The stack for a client tab: `NavigationStack(path: app.path(for: .home))`.
    func path(for tab: ClientTab) -> Binding<NavigationPath> {
        Binding(get: { self.clientPaths[tab] ?? NavigationPath() },
                set: { self.clientPaths[tab] = $0 })
    }

    /// The stack for a pro tab: `NavigationStack(path: app.path(for: .today))`.
    func path(for tab: ProTab) -> Binding<NavigationPath> {
        Binding(get: { self.proPaths[tab] ?? NavigationPath() },
                set: { self.proPaths[tab] = $0 })
    }

    init(data: DataService = MockDataService(), payments: PaymentService = MockPaymentService(), location: LocationService = LocationService()) {
        self.data = data
        self.payments = payments
        self.location = location
        let live = !(data is MockDataService)
        self.isLive = live
        self.isRestoring = live
        // Real pros and real inspo never show the bundled stock photos; the sample data does.
        BundledWork.standsInForWork = !live
        // The monitor calls back on its own queue; the answer is set on the main actor.
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status != .satisfied
            Task { @MainActor in
                guard let self, self.isOffline != offline else { return }
                self.isOffline = offline
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "app.hairdone.network"))
        // Saved or discarded the last unsaved pro edit: a notification tap that waited on it can open.
        ProUnsavedWork.shared.onCleared = { [weak self] in self?.unsavedWorkCleared() }
    }

    deinit { pathMonitor.cancel() }

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
        lastDataError = error as? DataError
        show(line)
    }

    /// Keeps the error for a screen to show inline, without a toast.
    private func note(_ error: Error) {
        lastError = error.localizedDescription
        lastDataError = error as? DataError
    }

    // MARK: Session

    /// Picks up a saved session at launch. Straight to Home if she's finished onboarding before.
    /// Called once, from the app's launch task.
    func restoreSession() async {
        // From here, notification taps reach the app (one that launched it is opened once she's in).
        PushCenter.shared.attach(self)
        guard let restored = await data.currentClient() else {
            isRestoring = false
            return
        }
        client = restored
        proSelf = await data.currentPro()
        restoreMode()
        stage = restored.firstName.isEmpty ? .signedIn : .ready
        isRestoring = false
        registerForPush()
        // Whichever side she lands on (Pro mode is remembered), everything loads now. This also
        // covers the app coming forward while the session was still being picked up.
        Task { await self.refreshAll() }
        if stage == .ready, let waiting = pendingPush {
            pendingPush = nil
            open(waiting)
        } else if stage == .ready, let link = pendingProLink {
            pendingProLink = nil
            openProLink(link)
        }
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
            await signedIn()
        } catch { signInFailed(error) }
    }

    /// Emails a code. False (with `lastError` and `signInFailure` set) if it didn't go.
    @discardableResult
    func sendEmailCode(to email: String) async -> Bool {
        do {
            try await data.sendEmailCode(email: email)
            lastError = nil
            signInFailure = nil
            return true
        } catch {
            signInFailed(error)
            return false
        }
    }

    func verifyEmailCode(_ code: String, email: String) async {
        do {
            client = try await data.verifyEmailCode(email: email, code: code)
            await signedIn()
        } catch { signInFailed(error) }
    }

    func signInWithApple(_ credential: AppleCredential) async {
        do {
            client = try await data.signInWithApple(credential)
            await signedIn()
        } catch { signInFailed(error) }
    }

    private func signedIn() async {
        proSelf = await data.currentPro()
        restoreMode()
        lastError = nil
        signInFailure = nil
        stage = .signedIn
        registerForPush()
        // Her bookings, threads and pro side start loading while she finishes the name and
        // location steps; `finishOnboarding` loads again with where she is.
        Task { await self.refreshAll() }
    }

    private func signInFailed(_ error: Error) {
        lastError = error.localizedDescription
        signInFailure = error as? DataError
    }

    func finishOnboarding() {
        stage = .ready
        let named = client
        Task {
            // Saves the name from onboarding. On the real backend this makes her profile the first time.
            if let named { try? await self.data.updateClient(named) }
            await self.refreshAll()
        }
        if let link = pendingProLink {
            pendingProLink = nil
            openProLink(link)
        }
    }

    func signOut() {
        wantsProOnboarding = false
        let data = self.data
        // The token comes off the account first, while there's still a session to do it with.
        let token = PushCenter.savedToken
        Task {
            if let token { try? await data.unregisterDevice(token: token) }
            await data.signOut()
        }
        stage = .welcome
        mode = .client
        client = nil
        // Both builds: the next person on this phone mustn't see her pro side.
        proSelf = nil
        bookings = []; proBookings = []; threads = []; otherSideThreads = []; pros = []; payouts = []
        knownPros = [:]; proDetails = [:]; clientNames = [:]; blockedIDs = []
        whosFree = [:]; searchResults = []; searchQuery = ""; isSearching = false
        prosLoadFailed = false; bookingsLoadFailed = false; threadsLoadFailed = false; proSideLoadFailed = false
        clientNamesLookedUp = []
        hasLoadedBookings = false; hasLoadedThreads = false; hasLoadedProSide = false; hasLoadedOnce = false
        pendingCheckout = nil
        pendingRoute = nil; pendingPush = nil; pendingProLink = nil; openThreadID = nil
        selectedTab = .home; selectedProTab = .today
        clientPaths = [:]; proPaths = [:]
    }

    /// App Store rule: an account can be deleted from the app. False (with `lastError`) if it wasn't.
    func deleteAccount() async -> Bool {
        lastDataError = nil
        do {
            try await data.deleteAccount()
            signOut()
            return true
        } catch {
            note(error)
            return false
        }
    }

    func switchMode(_ new: AppMode) {
        Haptics.medium()
        setMode(new)
        Task { await self.refreshAll() }
    }

    /// Changes side, swapping the threads straight away (the other side's are already loaded) and
    /// remembering the side for next launch.
    private func setMode(_ new: AppMode) {
        guard new != mode else { return }
        let current = threads
        threads = otherSideThreads
        otherSideThreads = current
        withAnimation(Motion.spring) { mode = new }
        if let id = client?.id { UserDefaults.standard.set(new.rawValue, forKey: Self.modeKey(id)) }
    }

    private static func modeKey(_ userID: String) -> String { "mode.\(userID)" }

    /// Back to the side she was last on, if that's Pro mode and she still has an open pro profile.
    private func restoreMode() {
        guard let id = client?.id else { return }
        let saved = UserDefaults.standard.string(forKey: Self.modeKey(id)).flatMap(AppMode.init(rawValue:))
        let canBePro = proSelf.map { !$0.isClosed } ?? false
        mode = saved == .pro && canBePro ? .pro : .client
    }

    // MARK: Loading

    /// Everything, both sides. A second call while one's going waits for that one.
    func refreshAll() async {
        if let running = refreshing {
            await running.value
            return
        }
        let task = Task { await self.loadEverything() }
        refreshing = task
        await task.value
        refreshing = nil
        hasLoadedOnce = true
    }

    private func loadEverything() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadPros() }
            group.addTask { await self.loadBookings(people: false) }
            group.addTask { await self.loadThreads(people: false) }
            group.addTask { await self.loadProSide(people: false) }
        }
        await loadPeople()
    }

    /// Skeletons only before the first answer: never over what's already there, and never for a
    /// load that failed (that screen shows `ErrorState`).
    var showsBookingsSkeleton: Bool {
        client != nil && bookings.isEmpty && !hasLoadedBookings && !bookingsLoadFailed
    }
    var showsThreadsSkeleton: Bool {
        threads.isEmpty && !hasLoadedThreads && !threadsLoadFailed && (client != nil || proSelf != nil)
    }
    var showsProSideSkeleton: Bool {
        proSelf != nil && proBookings.isEmpty && payouts.isEmpty && !hasLoadedProSide && !proSideLoadFailed
    }

    /// Pros near her, and who's free today, together.
    func loadPros(category: Category? = nil) async {
        isLoadingPros = true
        defer { isLoadingPros = false }
        async let free: Void = loadWhosFree(category: category)
        do {
            if isLive && client != nil { blockedIDs = (try? await data.blockedIDs()) ?? blockedIDs }
            let blocked = blockedIDs
            pros = try await data.pros(near: location.coordinate, category: category).filter { !blocked.contains($0.id) }
            prosLoadFailed = false
        } catch {
            prosLoadFailed = true
            lastError = error.localizedDescription
        }
        await free
    }

    /// Who's free today, from her real slots. Empty if it didn't load; the list itself says when that's a failure.
    func loadWhosFree(category: Category?) async {
        do {
            whosFree = try await data.whosFree(near: location.coordinate, category: category)
        } catch {
            whosFree = [:]
        }
    }

    /// Server search. Under two characters it clears the results instead.
    func search(_ query: String) async {
        let words = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchQuery = words
        guard words.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        do {
            let found = try await data.searchPros(words, near: location.coordinate)
            guard searchQuery == words else { return }
            let blocked = blockedIDs
            searchResults = found.filter { !blocked.contains($0.id) }
            for p in searchResults where knownPros[p.id] == nil && !pros.contains(where: { $0.id == p.id }) { knownPros[p.id] = p }
        } catch {
            guard searchQuery == words else { return }
            searchResults = []
            lastError = error.localizedDescription
        }
        isSearching = false
    }

    func loadBookings(people: Bool = true) async {
        guard let client else { return }
        isLoadingBookings = true
        defer { isLoadingBookings = false }
        do {
            bookings = try await data.bookings(clientID: client.id)
            bookingsLoadFailed = false
            hasLoadedBookings = true
        } catch {
            bookingsLoadFailed = true
            lastError = error.localizedDescription
        }
        if people { await loadPeople() }
    }

    /// Both sides' threads in one go, split by side: `threads` for the side she's on, `otherSideThreads` for the other.
    func loadThreads(people: Bool = true) async {
        let clientID = client?.id ?? ""
        let proID = proSelf?.id ?? ""
        guard !clientID.isEmpty || !proID.isEmpty else { return }
        isLoadingThreads = true
        defer { isLoadingThreads = false }
        do {
            var all = try await data.threads(userID: clientID.isEmpty ? proID : clientID)
            // The sample data keeps her pro self under another id; the real server sends both sides at once.
            if !proID.isEmpty && !clientID.isEmpty && proID != clientID {
                let more = try await data.threads(userID: proID)
                let seen = Set(all.map(\.id))
                all += more.filter { !seen.contains($0.id) }
            }
            let asPro = all.filter { !proID.isEmpty && $0.proID == proID }
            let asClient = all.filter { !clientID.isEmpty && $0.clientID == clientID }
            // The side she's on now, which may have changed while this loaded.
            if mode == .pro {
                threads = asPro
                otherSideThreads = asClient
            } else {
                threads = asClient
                otherSideThreads = asPro
            }
            threadsLoadFailed = false
            hasLoadedThreads = true
        } catch {
            threadsLoadFailed = true
            lastError = error.localizedDescription
        }
        if people { await loadPeople() }
    }

    func loadProSide(people: Bool = true) async {
        guard let proSelf else { return }
        isLoadingProSide = true
        defer { isLoadingProSide = false }
        do {
            proBookings = try await data.bookings(proID: proSelf.id)
            payouts = try await data.payouts(proID: proSelf.id)
            proSideLoadFailed = false
            hasLoadedProSide = true
        } catch {
            proSideLoadFailed = true
            lastError = error.localizedDescription
        }
        if people { await loadPeople() }
    }

    /// Fills in the pros and clients the lists mention but the nearby list doesn't have.
    func loadPeople() async {
        guard isLive else { return }
        let allThreads = threads + otherSideThreads
        var proIDs = Set(bookings.map(\.proID))
        proIDs.formUnion(allThreads.map(\.proID))
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
        clientIDs.formUnion(allThreads.map(\.clientID))
        if let own = client?.id { clientIDs.remove(own) }
        clientIDs.subtract(clientNames.keys)
        clientIDs.remove("")
        clientIDs.subtract(clientNamesLookedUp)
        if !clientIDs.isEmpty {
            await lookUpClientNames(Array(clientIDs))
        }
    }

    /// Asks for these clients' first names. Ids it asked about count as looked up when it answers,
    /// even with no name, so a nameless client doesn't shimmer for ever. A failed lookup tries again
    /// next load.
    private func lookUpClientNames(_ ids: [String]) async {
        guard let names = try? await data.clientNames(ids: ids) else { return }
        clientNames.merge(names) { _, new in new }
        clientNamesLookedUp.formUnion(ids)
    }

    /// Her whole profile, for when it's opened from a list that only had the card.
    func loadProDetail(_ id: String) async {
        guard let full = try? await data.pro(id: id) else { return }
        proDetails[id] = full
    }

    /// The Stripe link for payout setup. Nil, with the "didn't open" alert up, if it didn't come.
    func payoutLink() async -> URL? {
        do {
            return try await payments.payoutOnboardingURL(proID: proSelf?.id ?? client?.id ?? "new")
        } catch {
            payoutNotice = .didntOpen
            return nil
        }
    }

    /// Back from Stripe's payout setup: `finished` for `hairdone://payouts/done`, false for `/refresh`
    /// (the link ran out). The server asks Stripe directly; when she's finished, Stripe can take a
    /// moment to switch payouts on, so it looks a few times.
    func payoutsReturned(finished: Bool) async {
        var answer: Bool? = nil
        for attempt in 0..<(finished ? 3 : 1) {
            let reply = try? await data.payoutStatus()
            if let reply { answer = reply }
            if answer == true { break }
            if attempt < 2 && finished { try? await Task.sleep(for: .seconds(3)) }
        }
        if let answer, var pro = proSelf, pro.payoutsConnected != answer {
            pro.payoutsConnected = answer
            proSelf = pro
        }
        if answer == true {
            show("Payouts on. Daily, to your bank.")
        } else {
            payoutNotice = finished ? .stillChecking : .linkExpired
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

    /// A client's first name for the pro side. Empty while it's still on its way (live backend only);
    /// check `isClientNameKnown` and show a shimmer instead of a blank. "Client" only once the lookup
    /// has come back with no name.
    func clientName(_ id: String) -> String {
        if id == client?.id { return client?.firstName ?? "You" }
        if let name = clientNames[id], !name.isEmpty { return name }
        guard isLive else { return MockData.clientNames[id] ?? "Client" }
        return clientNamesLookedUp.contains(id) ? "Client" : ""
    }

    /// False while a client's name is still loading (live backend). Show `SkeletonBlock` in its place.
    func isClientNameKnown(_ id: String) -> Bool {
        if !isLive || id == client?.id { return true }
        if let name = clientNames[id], !name.isEmpty { return true }
        return clientNamesLookedUp.contains(id)
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

    /// The dot on You in booking mode: something's waiting on her pro side.
    var clientYouBadge: Bool { mode == .client && (!openRequests.isEmpty || otherSideUnreadCount > 0) }

    var unreadCount: Int {
        threads.reduce(0) { $0 + (mode == .pro ? $1.unreadForPro : $1.unreadForClient) }
    }

    /// Unread messages waiting on the side she isn't on.
    var otherSideUnreadCount: Int {
        otherSideThreads.reduce(0) { $0 + (mode == .pro ? $1.unreadForClient : $1.unreadForPro) }
    }

    /// Her pro requests waiting for an answer, the one that lapses first at the top.
    var openRequests: [Booking] {
        proBookings.filter { $0.status == .requested }.sorted { requestDeadline($0) < requestDeadline($1) }
    }

    /// When a request lapses if she hasn't answered: two hours after it came in, as the server does it.
    func requestDeadline(_ b: Booking) -> Date { b.createdAt.adding(hours: Fees.autoDeclineHours) }

    /// Paid jobs that aren't in a payout yet.
    private var unpaidOut: [Booking] {
        let paidOut = Set(payouts.flatMap(\.bookingIDs))
        return proBookings.filter { $0.status == .paid && !paidOut.contains($0.id) }
    }

    /// What's on its way to her: her share of paid jobs not yet in a payout.
    var pendingEarningsCents: Int { unpaidOut.reduce(0) { $0 + $1.price.proPayoutCents } }

    /// The next business day after the last of those jobs was paid. Nil when nothing's waiting.
    var nextPayoutDate: Date? {
        let paidAt = unpaidOut.map { b in b.events.last(where: { $0.status == .paid })?.at ?? b.start }
        guard let last = paidAt.max() else { return nil }
        var day = last.startOfDay.adding(days: 1)
        while day.weekday == .saturday || day.weekday == .sunday { day = day.adding(days: 1) }
        return day
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

    /// False (with `lastError` set) if it didn't move. The server writes the new time in the thread.
    @discardableResult
    func reschedule(_ booking: Booking, to start: Date) async -> Bool {
        lastError = nil
        do {
            replace(try await data.reschedule(bookingID: booking.id, to: start))
            await loadThreads(people: false)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Leaves the review. On a done booking that isn't paid yet, this is also "Pay": the charge and any tip go through first.
    /// If the payment goes through and the review doesn't, the booking still shows as paid.
    /// Pays for a done booking with the tip. The review is separate and optional. False (with `lastError`) if it didn't go.
    @discardableResult
    func pay(_ booking: Booking, tipCents: Int) async -> Bool {
        if isOffline { fail(DataError.offline); return false }
        do {
            replace(try await data.pay(bookingID: booking.id, tipCents: tipCents))
            Haptics.success()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func review(_ booking: Booking, rating: Int, text: String, tipCents: Int) async -> ReviewOutcome {
        do {
            replace(try await data.submitReview(bookingID: booking.id, rating: rating, text: text, tipCents: tipCents))
            Haptics.success()
            await loadPros()
            if isLive { await loadProDetail(booking.proID) }
            return .saved
        } catch DataError.paidReviewNotSaved {
            let fresh = try? await data.booking(id: booking.id)
            if let fresh {
                replace(fresh)
            } else {
                var paid = booking
                paid.status = .paid
                replace(paid)
            }
            Haptics.success()
            show(DataError.paidReviewNotSaved.errorDescription ?? "")
            return .paidOnly
        } catch {
            lastError = error.localizedDescription
            return .failed(error.localizedDescription)
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

    /// False if it didn't send, so the composer can put the words back.
    @discardableResult
    func send(_ text: String, in thread: MessageThread) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        do {
            let updated = try await data.send(text: trimmed, threadID: thread.id, senderID: userID)
            if let i = threads.firstIndex(where: { $0.id == thread.id }) { threads[i] = updated }
            return true
        } catch {
            fail(error)
            return false
        }
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

    /// Shows the change straight away. False (with `lastError` set, and the old profile back) if it didn't save.
    @discardableResult
    func saveProSelf(_ pro: Pro) async -> Bool {
        let before = proSelf
        proSelf = pro
        do {
            let saved = try await data.updatePro(pro)
            proSelf = saved
            // Her name is one name on both sides. (The sample data's pro is someone else, so not there.)
            if isLive, var c = client, !saved.firstName.isEmpty, c.firstName != saved.firstName {
                c.firstName = saved.firstName
                client = c
            }
            return true
        } catch {
            proSelf = before
            fail(error)
            return false
        }
    }

    /// Closes her pro profile and takes her back to booking. False, with `lastError`, while she has a job that isn't finished.
    @discardableResult
    func closeProProfile() async -> Bool {
        guard isOnline() else { return false }
        do {
            try await data.closeProProfile()
            if var p = proSelf {
                p.isClosed = true
                p.isActive = false
                proSelf = p
            }
            if mode == .pro { switchMode(.client) }
            return true
        } catch DataError.liveBooking {
            fail(CloseRefused())
            lastDataError = .liveBooking
            return false
        } catch {
            fail(error)
            return false
        }
    }

    /// Opens her pro profile again, with her work and prices as she left them.
    @discardableResult
    func reopenProProfile() async -> Bool {
        guard isOnline() else { return false }
        do {
            try await data.reopenProProfile()
            if let fresh = await data.currentPro() {
                proSelf = fresh
            } else if var p = proSelf {
                p.isClosed = false
                p.isActive = true
                proSelf = p
            }
            return true
        } catch {
            fail(error)
            return false
        }
    }

    /// The close was refused because a job isn't finished.
    private struct CloseRefused: LocalizedError {
        var errorDescription: String? { "Finish or cancel your jobs first." }
    }

    // MARK: Photos and ID

    /// A work photo, uploaded. Put the URL in `WorkItem.imageURL`, then `saveProSelf`. Nil (with a toast) if it didn't go.
    func uploadWorkPhoto(_ jpeg: Data) async -> URL? {
        guard isOnline() else { return nil }
        do { return try await data.uploadWorkPhoto(jpeg) } catch { fail(error); return nil }
    }

    /// Her profile photo, uploaded and saved, on both sides. Nil (with a toast) if it didn't go.
    func uploadAvatar(_ jpeg: Data) async -> URL? {
        guard isOnline() else { return nil }
        do {
            let url = try await data.uploadAvatar(jpeg)
            client?.avatarURL = url
            proSelf?.avatarURL = url
            return url
        } catch {
            fail(error)
            return nil
        }
    }

    @discardableResult
    func uploadIDDocument(_ jpeg: Data, kind: IDDocumentKind) async -> Bool {
        guard isOnline() else { return false }
        do {
            try await data.uploadIDDocument(jpeg, kind: kind)
            return true
        } catch {
            fail(error)
            return false
        }
    }

    /// Sends her ID for a person to check. Only the server sets "ID checked".
    @discardableResult
    func submitIDCheck() async -> Bool {
        guard isOnline() else { return false }
        do {
            try await data.submitIDCheck()
            proSelf?.idSubmitted = true
            return true
        } catch {
            fail(error)
            return false
        }
    }

    // MARK: Phone

    /// Texts a code to the new number. False (with a toast) if it didn't go.
    @discardableResult
    func changePhone(to phone: String) async -> Bool {
        guard isOnline() else { return false }
        do {
            try await data.changePhone(to: phone)
            lastError = nil
            return true
        } catch {
            fail(error)
            return false
        }
    }

    /// The code for the new number. On true, `client.phone` is the new number and it's how she signs in.
    @discardableResult
    func verifyPhoneChange(_ code: String, phone: String) async -> Bool {
        guard isOnline() else { return false }
        do {
            client = try await data.verifyPhoneChange(phone: phone, code: code)
            lastError = nil
            return true
        } catch {
            fail(error)
            return false
        }
    }

    /// False, with the offline toast, when there's no network.
    private func isOnline() -> Bool {
        guard isOffline else { return true }
        fail(DataError.offline)
        return false
    }

    // MARK: Links

    /// The link "Share" sends for a pro. This should become https://hairdonenailsdone.app/pro/<id> once the domain
    /// serves apple-app-site-association, so it opens the app for people who have it and the site for
    /// people who don't.
    func shareURL(for pro: Pro) -> URL {
        URL(string: "hairdone://pro/\(pro.id)") ?? URL(string: "hairdone://pro")!
    }

    /// A pro link was opened (hairdone://pro/<id>): her profile, on Home, in booking mode. Waits for
    /// sign-in; ignored, with a toast, while she's in the middle of something.
    func openProLink(_ id: String) {
        guard !id.isEmpty else { return }
        guard stage == .ready, !isRestoring, client != nil else {
            pendingProLink = id
            return
        }
        if busySurfaces > 0 {
            show("Finish this first, then open the link again.")
            return
        }
        if hasUnsavedProWork {
            show("Save or discard your changes, then open the link again.")
            return
        }
        Task { await self.routeToPro(id) }
    }

    private func routeToPro(_ id: String) async {
        await loadProDetail(id)
        guard let found = pro(id) else {
            show("We couldn't find her. The link might be old.")
            return
        }
        guard enter(.client) else {
            show("Save or discard your changes, then open the link again.")
            return
        }
        selectedTab = .home
        pendingRoute = .pro(found)
    }

    // MARK: Push notifications

    /// After sign-in and whenever the app comes forward: if she's allowed notifications, get the
    /// token (again). It lands in `deviceTokenArrived`.
    func registerForPush() {
        guard client != nil else { return }
        PushCenter.shared.registerIfAllowed()
    }

    /// Back in the foreground: register for pushes, and catch up on bookings, messages and (for a
    /// pro) requests, so nothing's missed even without a push.
    func becameActive() {
        // On a cold start the app is active before the saved session is back; `restoreSession`
        // runs the full load (`refreshAll`) once it is, so nothing is missed by stopping here.
        if isRestoring { return }
        guard stage != .welcome else { return }
        registerForPush()
        guard stage == .ready else { return }
        // A full load is already going (launch, sign-in, a switch): that covers this.
        if refreshing != nil { return }
        Task {
            await self.loadBookings(people: false)
            await self.loadThreads(people: false)
            if self.proSelf != nil { await self.loadProSide(people: false) }
            await self.loadPeople()
        }
    }

    /// One of the `busySurfaces` closed. If that was the last and a tap is waiting, open it now.
    func surfaceClosed() {
        busySurfaces = max(0, busySurfaces - 1)
        openWaitingPush()
    }

    /// Pro edits she hadn't saved were saved or discarded (`ProUnsavedWork`). A tap waiting on them can open.
    func unsavedWorkCleared() {
        openWaitingPush()
    }

    private func openWaitingPush() {
        guard busySurfaces == 0, !hasUnsavedProWork, stage == .ready, let waiting = pendingPush else { return }
        pendingPush = nil
        Task {
            // Let the sheet finish going before the tabs move.
            try? await Task.sleep(for: .milliseconds(450))
            self.open(waiting)
        }
    }

    /// Hours or profile edits in Pro mode she hasn't saved. A notification never switches sides or
    /// moves a tab underneath them; it waits, as it does for `busySurfaces`.
    var hasUnsavedProWork: Bool { mode == .pro && ProUnsavedWork.shared.hasAny }

    func deviceTokenArrived(_ token: String) {
        guard client != nil else { return }
        let data = self.data
        Task { try? await data.registerDevice(token: token, environment: PushCenter.environment) }
    }

    /// Our pre-prompt for this side, if it's never been shown and iOS hasn't asked yet.
    func shouldAskForPush(_ side: PushAskSide) async -> Bool {
        guard client != nil else { return false }
        return await PushCenter.shared.shouldAsk(side)
    }

    /// A notification came in while the app's open: refresh whatever it's about.
    func pushArrived(_ target: PushTarget) {
        guard stage == .ready else { return }
        Task {
            switch target.kind {
            case .booking:
                await self.loadBookings(people: false)
                await self.loadProSide(people: false)
            case .message:
                await self.loadThreads(people: false)
            }
            await self.loadPeople()
        }
    }

    /// A notification was tapped: switch to the side it's for and open the booking or the thread.
    func open(_ target: PushTarget) {
        guard stage == .ready, !isRestoring, client != nil else {
            pendingPush = target
            return
        }
        // Never switch sides or move things under her while she's in the middle of something,
        // or while she has pro edits she hasn't saved (the same rule the Switch row asks about).
        if busySurfaces > 0 || hasUnsavedProWork {
            pendingPush = target
            let unsaved = busySurfaces == 0
            Task { await self.sayWaiting(target, unsaved: unsaved) }
            return
        }
        Task { await self.route(to: target) }
    }

    /// "New request from Ruby. We'll open it when you're done here." Shown on the sheet she's in.
    private func sayWaiting(_ target: PushTarget, unsaved: Bool = false) async {
        let side = target.side ?? mode
        var name: String? = nil
        var isRequest = false
        var found: Booking? = nil
        if let id = target.bookingID { found = try? await data.booking(id: id) }
        if let b = found {
            isRequest = b.status == .requested
            if side == .pro {
                if !isClientNameKnown(b.clientID) { await lookUpClientNames([b.clientID]) }
                let n = clientName(b.clientID)
                name = n.isEmpty || n == "Client" ? nil : n
            } else {
                name = pro(b.proID)?.firstName
            }
        }
        let lead: String
        switch target.kind {
        case .message:
            lead = name.map { "New message from \($0)." } ?? "New message."
        case .booking:
            if side == .pro {
                lead = isRequest ? (name.map { "New request from \($0)." } ?? "New request.")
                                 : (name.map { "Update on \($0)'s booking." } ?? "Update on a booking.")
            } else {
                lead = name.map { "\($0) has an update on your booking." } ?? "An update on your booking."
            }
        }
        show(unsaved ? "\(lead) Save or discard your changes and we'll open it."
                     : "\(lead) We'll open it when you're done here.")
    }

    private func route(to target: PushTarget) async {
        switch target.kind {
        case .message:
            if let threadID = target.threadID {
                let which: AppMode
                if let given = target.side { which = given } else { which = await side(forThread: threadID) }
                guard enter(which) else { return hold(target) }
                await loadThreads()
                if mode == .pro { selectedProTab = .inbox } else { selectedTab = .inbox }
                pendingRoute = .thread(threadID)
            } else if let bookingID = target.bookingID {
                await route(toBooking: bookingID, side: target.side, for: target)
            }
        case .booking:
            if let bookingID = target.bookingID { await route(toBooking: bookingID, side: target.side, for: target) }
        }
    }

    /// Edits turned up while the tap was being worked out: it waits for them, like any other.
    private func hold(_ target: PushTarget) {
        pendingPush = target
        Task { await self.sayWaiting(target, unsaved: true) }
    }

    /// A pro's own job opens on her side (Today, then the job); anything else on the client side.
    /// `side` comes from the push; without it, the booking says whose it is.
    private func route(toBooking id: String, side: AppMode?, for target: PushTarget) async {
        let which: AppMode
        if let side {
            which = side
        } else {
            let found = try? await data.booking(id: id)
            let isHers = found != nil && proSelf != nil && found?.proID == proSelf?.id
            which = isHers ? .pro : .client
        }
        guard enter(which) else { return hold(target) }
        if mode == .pro {
            await loadProSide()
            selectedProTab = .today
            pendingRoute = .proBooking(id)
        } else {
            await loadBookings()
            selectedTab = .bookings
            pendingRoute = .booking(id)
        }
    }

    private func side(forThread id: String) async -> AppMode {
        guard let me = proSelf?.id else { return .client }
        if let known = threads.first(where: { $0.id == id }) { return known.proID == me ? .pro : .client }
        let fetched = try? await data.thread(id: id)
        if let fetched { return fetched.proID == me ? .pro : .client }
        return mode
    }

    /// Switches sides for a notification, without the haptic and refresh a tap on the switch gets.
    /// False, without switching, when leaving Pro mode would drop edits she hasn't saved.
    @discardableResult
    private func enter(_ side: AppMode) -> Bool {
        guard side != mode else { return true }
        if side == .pro && proSelf == nil { return true }
        if mode == .pro && ProUnsavedWork.shared.hasAny { return false }
        setMode(side)
        return true
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
/// Work lives in Profile now, pushed as `Route.proWork`.
enum ProTab: String, CaseIterable { case today, calendar, inbox, earnings, profile }
