import SwiftUI

/// The You tab: who you are, the way into Pro mode (right under your name), where she comes to,
/// how you pay, who you'd book again, and the quiet bits at the bottom.
struct AccountView: View {
    @Environment(AppState.self) private var app
    @State private var path = NavigationPath()

    @State private var showDetails = false
    @State private var showAddresses = false
    @State private var showPayments = false
    @State private var showNotifications = false
    @State private var showHelp = false
    @State private var showLegal = false
    @State private var showProOnboarding = false
    @State private var reopening = false
    @State private var confirmLogout = false
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var refusal: DeleteRefusal? = nil

    /// Why delete didn't go through, and the booking that's in the way if we can tell which.
    struct DeleteRefusal: Identifiable {
        let id = UUID()
        var title: String = "Not yet."
        var line: String
        var booking: Booking?
        var isProSide: Bool
    }

    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let client = app.client {
                        header(client)
                            .screenGutter()
                            .padding(.top, Space.s)
                        if app.isOffline { OfflineBar().padding(.top, Space.l) }
                        proModeBlock
                            .screenGutter()
                            .padding(.top, Space.xl)
                        settings(client)
                            .screenGutter()
                            .padding(.top, Space.section)
                        favourites
                            .padding(.top, Space.section)
                        about
                            .screenGutter()
                            .padding(.top, Space.section)
                    }
                    quietActions
                        .screenGutter()
                        .padding(.top, Space.xl)
                }
                .padding(.bottom, Space.section)
            }
            .paperBackground()
            .toolbar(.hidden, for: .navigationBar)
            .hdDestinations()
            .animation(Motion.gentle, value: app.isOffline)
            .confirmSheet(isPresented: $confirmLogout,
                          title: "Log out?",
                          message: "Your bookings stay put. You'll need a new code to get back in.",
                          confirmTitle: "Log out",
                          cancelTitle: "Stay") { app.signOut() }
            .confirmSheet(isPresented: $confirmDelete,
                          title: "Delete your account?",
                          message: deleteMessage,
                          confirmTitle: "Delete",
                          cancelTitle: "Keep it") { deleteAccount() }
            .sheet(item: $refusal) { r in refusalSheet(r) }
            .sheet(isPresented: $showDetails) { AccountDetailsSheet() }
            .sheet(isPresented: $showAddresses) { AccountAddressesSheet() }
            .sheet(isPresented: $showPayments) { AccountPaymentsSheet() }
            .sheet(isPresented: $showNotifications) { AccountNotificationsSheet() }
            .sheet(isPresented: $showHelp) { AccountHelpSheet() }
            .sheet(isPresented: $showLegal) { AccountLegalSheet() }
            .fullScreenCover(isPresented: $showProOnboarding) {
                ProOnboardingFlow {
                    showProOnboarding = false
                    app.switchMode(.pro)
                }
            }
            .onAppear { takeProIntent() }
            .onChange(of: app.wantsProOnboarding) { _, _ in takeProIntent() }
        }
    }

    // MARK: Header

    private func header(_ client: Client) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Booking since \(client.joined.hdMonthYear)").labelStyle()
            Text(client.firstName.isEmpty ? "You." : "\(client.firstName).")
                .font(HDFont.display)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            // Phone first; Apple and email sign-ins show the email, or ask for a mobile.
            if !client.phone.isEmpty {
                Text(client.phone).font(HDFont.sub.monospacedDigit()).foregroundStyle(Palette.inkSoft)
            } else if !client.email.isEmpty {
                Text(client.email).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            } else {
                TertiaryButton(title: "Add your mobile", tint: Palette.ink) { showDetails = true }
                    .padding(.leading, -8)
            }
        }
    }

    // MARK: Pro mode

    private var waitingLine: String? {
        let requests = app.openRequests.count
        let messages = app.mode == .client ? app.otherSideUnreadCount : 0
        var parts: [String] = []
        if requests > 0 { parts.append(requests == 1 ? "1 request waiting" : "\(requests) requests waiting") }
        if messages > 0 { parts.append(messages == 1 ? "1 message" : "\(messages) messages") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private enum ProState { case notPro, closed, draft, open }

    /// The onboarding step she got to on this phone, if she's left it part way.
    private var draftStep: Int? {
        guard let id = app.client?.id else { return nil }
        return ProOnboardingDraft.stepReached(userID: id)
    }

    private var proState: ProState {
        guard let pro = app.proSelf else { return draftStep == nil ? .notPro : .draft }
        if pro.isClosed { return .closed }
        if !pro.isOnboarded { return .draft }
        return .open
    }

    /// The ink row that previews Pro mode's ink: what she gets, what's waiting, and the switch.
    private var proModeBlock: some View {
        let state = proState
        let title: String
        let line: String
        let button: String
        switch state {
        case .notPro:
            title = "Get booked."
            line = "Do hair, nails, makeup, lashes or brows? Set up takes about ten minutes."
            button = "Set up Pro mode"
        case .closed:
            title = "Get booked."
            line = "Welcome back. We kept your work and prices."
            button = "Set up Pro mode"
        case .draft:
            title = "Pro mode"
            line = draftStep.map { "Pick up where you left off. Step \($0) of 7." }
                ?? "Pick up where you left off. Clients can't see you until it's done."
            button = "Keep going"
        case .open:
            title = "Pro mode"
            line = app.proSelf?.displayName ?? ""
            button = "Switch to Pro mode"
        }
        return VStack(alignment: .leading, spacing: Space.s) {
            if state == .notPro || state == .closed {
                Text("Pro mode").eyebrowStyle(color: Palette.onInkSoft)
            }
            Text(title)
                .font(HDFont.name)
                .foregroundStyle(Palette.onInk)
                .accessibilityAddTraits(.isHeader)
            Text(line)
                .font(HDFont.sub)
                .foregroundStyle(Palette.onInkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if let waitingLine, state != .notPro {
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    Circle().fill(Palette.warn).frame(width: 6, height: 6)
                        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 1 }
                        .accessibilityHidden(true)
                    Text(waitingLine)
                        .font(HDFont.subMedium)
                        .foregroundStyle(Palette.onInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, Space.xs)
            }
            InkButton(title: button, isLoading: reopening, isEnabled: state == .open || !app.isOffline, tone: .onInk, compact: true) {
                proAction(state)
            }
            .padding(.top, Space.s)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .inkBlock(padding: Space.l + 4)
        .accessibilityElement(children: .contain)
    }

    private func proAction(_ state: ProState) {
        switch state {
        case .notPro, .draft:
            showProOnboarding = true
        case .open:
            app.switchMode(.pro)
        case .closed:
            reopening = true
            Task { @MainActor in
                let back = await app.reopenProProfile()
                reopening = false
                if back { app.switchMode(.pro) }
            }
        }
    }

    /// Welcome's "Get booked here." link: once she's signed in and on You, start pro setup.
    private func takeProIntent() {
        guard app.wantsProOnboarding, app.stage == .ready, app.client != nil else { return }
        app.wantsProOnboarding = false
        Task { @MainActor in
            // Let the shell finish arriving before a cover goes up over it.
            try? await Task.sleep(for: .milliseconds(600))
            switch proState {
            case .open: app.switchMode(.pro)
            case .closed: proAction(.closed)
            case .notPro, .draft: showProOnboarding = true
            }
        }
    }

    // MARK: Settings

    private func settings(_ client: Client) -> some View {
        VStack(spacing: 0) {
            Hairline(strong: true)
            HairlineRow(title: "Your details", value: client.firstName) { showDetails = true }
            HairlineRow(title: "Addresses", value: client.addresses.isEmpty ? "None yet" : "\(client.addresses.count)") { showAddresses = true }
            HairlineRow(title: "Payment methods", value: client.defaultPayment?.label ?? "None yet") { showPayments = true }
            HairlineRow(title: "Notifications") { showNotifications = true }
            HairlineRow(title: "Help", subtitle: "A person replies, usually the same day.") { showHelp = true }
        }
    }

    // MARK: Favourites

    private var favourites: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: "Favourites").screenGutter()
            if app.favouritePros.isEmpty {
                Text("No favourites yet. Tap Save on a pro you'd book again.")
                    .font(HDFont.sub)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .screenGutter()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Space.m) {
                        ForEach(app.favouritePros) { pro in
                            HomePortraitTile(item: pro.homeCover,
                                             width: 120, title: pro.firstName, line: pro.specialtyLine) {
                                path.append(Route.pro(pro))
                            }
                        }
                    }
                    .padding(.horizontal, Space.gutter)
                }
            }
        }
    }

    // MARK: About

    private var about: some View {
        VStack(alignment: .leading, spacing: 0) {
            Hairline(strong: true)
            HairlineRow(title: "Terms and privacy") { showLegal = true }
            Text("Hair Done \(version)")
                .font(HDFont.caption)
                .foregroundStyle(Palette.inkSoft)
                .padding(.top, Space.m)
        }
    }

    // MARK: Log out, delete

    private var quietActions: some View {
        VStack(alignment: .leading, spacing: 0) {
            TertiaryButton(title: "Log out", tint: Palette.ink) { confirmLogout = true }
            if deleting {
                ProgressView().frame(minHeight: 44).padding(.horizontal, 8)
            } else {
                TertiaryButton(title: "Delete account") { confirmDelete = true }
                    .disabled(app.isOffline)
            }
        }
        .padding(.leading, -8)
    }

    private var deleteMessage: String {
        if app.proSelf != nil {
            return "Your bookings, your pro profile, your work photos and your payout link all go. Money already on its way still lands. Can't be undone."
        }
        return "Profile, addresses and cards go. Past receipts stay in your email. Can't be undone."
    }

    private func deleteAccount() {
        deleting = true
        Task { @MainActor in
            let gone = await app.deleteAccount()
            deleting = false
            if !gone { refusal = whyNot() }
        }
    }

    /// Why it didn't go. Only when the server said a booking is in the way (`liveBooking`) does it name
    /// one: the soonest unfinished, on either side. Any other failure shows that error as it is.
    private func whyNot() -> DeleteRefusal {
        let fallback = "That didn't go through. Nothing's been deleted. Try again."
        // AppState keeps the error as text, so match the liveBooking wording.
        guard let error = app.lastError, error == DataError.liveBooking.errorDescription else {
            return DeleteRefusal(title: "Didn't go through.", line: app.lastError ?? fallback, booking: nil, isProSide: false)
        }
        let mine = app.bookings.filter(\.isUnfinished).map { ($0, false) }
        let hers = app.proBookings.filter(\.isUnfinished).map { ($0, true) }
        guard let pick = (mine + hers).min(by: { $0.0.start < $1.0.start }) else {
            return DeleteRefusal(line: error, booking: nil, isProSide: false)
        }
        let (b, proSide) = pick
        let line: String
        if proSide {
            let name = app.clientName(b.clientID)
            let who = name.isEmpty || name == "Client" ? "a client" : name
            line = "You've got \(who) \(b.start.hdSpokenDay) in Pro mode. Finish or cancel it, then try again."
        } else {
            let name = app.pro(b.proID)?.firstName ?? "a booking"
            line = "You've got \(name) \(b.start.hdSpokenDay). Finish or cancel it, then try again."
        }
        return DeleteRefusal(line: line, booking: b, isProSide: proSide)
    }

    private func refusalSheet(_ r: DeleteRefusal) -> some View {
        ConfirmSheet(title: r.title,
                     message: r.line,
                     confirmTitle: r.booking == nil ? "OK" : "Open it",
                     cancelTitle: r.booking == nil ? "Close" : "Not now",
                     onConfirm: {
                         refusal = nil
                         guard let b = r.booking else { return }
                         Task { @MainActor in
                             try? await Task.sleep(for: .milliseconds(450))
                             openBooking(b, proSide: r.isProSide)
                         }
                     },
                     onCancel: { refusal = nil }) { EmptyView() }
            .confirmSheetPresentation()
    }

    private func openBooking(_ b: Booking, proSide: Bool) {
        if proSide {
            app.switchMode(.pro)
            app.selectedProTab = .today
            app.pendingRoute = .proBooking(b.id)
        } else {
            app.selectedTab = .bookings
            app.pendingRoute = .booking(b.id)
        }
    }
}

#Preview("You") {
    AccountView().environment(previewApp())
}
