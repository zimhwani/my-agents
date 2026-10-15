import SwiftUI

/// Her money. This week as the one big number, seven bars, what's on its way, how the 12% works,
/// and the payouts that have landed (once there are any).
struct ProEarningsView: View {
    @Environment(AppState.self) private var app
    @State private var showPayoutDetails = false
    /// Kept in `AppState`, so switching to booking and back lands on the same screen.
    private var path: Binding<NavigationPath> { app.path(for: ProTab.earnings) }

    private var monday: Date { ProWeek.monday(of: Date()) }
    private var thisWeek: Int { ProMoney.payout(app.proBookings, weekOf: monday) }
    private var lastWeek: Int { ProMoney.payout(app.proBookings, weekOf: monday.adding(days: -7)) }
    private var weekBookings: [Booking] {
        ProMoney.earning(app.proBookings).filter { ProWeek.contains($0.start, weekOf: monday) }
    }
    private var days: [(day: Date, cents: Int)] {
        ProWeek.days(from: monday).map { ($0, ProMoney.payout(app.proBookings, on: $0)) }
    }
    private var history: [Payout] { app.payouts.sorted { $0.date > $1.date } }
    private var nothingYet: Bool { ProMoney.earning(app.proBookings).isEmpty && app.payouts.isEmpty }

    var body: some View {
        NavigationStack(path: path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if app.isOffline { OfflineBar().padding(.horizontal, -Space.gutter) }
                    ProTabHeader("Earnings.").padding(.top, Space.s)
                    if app.proSideLoadFailed && app.proBookings.isEmpty {
                        ErrorState { Task { await app.loadProSide() } }
                            .padding(.horizontal, -Space.gutter)
                    } else if app.showsProSideSkeleton {
                        // Before the first load: not "Nothing yet." yet.
                        VStack(alignment: .leading, spacing: Space.l) {
                            SkeletonBlock(width: 80, height: 12)
                            SkeletonBlock(width: 180, height: 56)
                            SkeletonBlock(height: 88)
                        }
                        .padding(.top, Space.xl)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Loading")
                    } else if nothingYet {
                        EmptyState(title: "Nothing yet.", message: "It'll be here the day after your first booking.")
                            .padding(.horizontal, -Space.gutter)
                    } else {
                        VStack(alignment: .leading, spacing: Space.section) {
                            week
                            pending
                            breakdown
                            if !history.isEmpty { historySection }
                        }
                        .padding(.top, Space.xl)
                    }
                    HairlineRow(title: "Payout details", value: app.proSelf?.payoutsConnected == true ? "On" : "Not set up") {
                        showPayoutDetails = true
                    }
                    .padding(.top, Space.section)
                }
                .screenGutter()
                .padding(.bottom, Space.section)
            }
            .paperBackground()
            .refreshable { await app.loadProSide() }
            .toolbar(.hidden, for: .navigationBar)
            .hdDestinations()
            .sheet(isPresented: $showPayoutDetails) { PayoutDetailsSheet() }
            .proSideBanner()
        }
    }

    // MARK: This week

    private var week: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("This week").labelStyle()
                // Wraps rather than shrinks at large text sizes.
                Text(Money.format(thisWeek)).font(HDFont.priceHero).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(weekLine).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            bars
        }
    }

    private var weekLine: String {
        let count = ProFlow.count(weekBookings.count, "booking", "bookings")
        let diff = thisWeek - lastWeek
        let vs: String
        if lastWeek == 0 && thisWeek == 0 { vs = "Nothing last week either." }
        else if lastWeek == 0 { vs = "Nothing last week." }
        else if diff == 0 { vs = "Same as last week." }
        else if diff > 0 { vs = "\(Money.format(diff)) more than last week." }
        else { vs = "\(Money.format(-diff)) less than last week." }
        return "\(count) · \(vs)"
    }

    private var bars: some View {
        let maxCents = max(days.map(\.cents).max() ?? 0, 1)
        let height: CGFloat = 88
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(days, id: \.day) { entry in
                let isToday = Calendar.current.isDateInToday(entry.day)
                let h = entry.cents > 0 ? max(CGFloat(entry.cents) / CGFloat(maxCents) * height, 6) : 2
                VStack(spacing: 6) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: Radius.photo, style: .continuous)
                            .fill(entry.cents > 0 ? Palette.ink : Palette.line)
                            .frame(height: h)
                    }
                    .frame(height: height)
                    Text(entry.day.weekday.short.prefix(1))
                        .font(HDFont.caption)
                        .fontWeight(isToday ? .semibold : .regular)
                        .foregroundStyle(isToday ? Palette.ink : Palette.inkSoft)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(entry.day.weekday.long), \(Money.format(entry.cents))")
            }
        }
        .animation(Motion.spring, value: days.map(\.cents))
    }

    // MARK: On its way

    private var pending: some View {
        let cents = app.pendingEarningsCents
        let title: String
        let sub: String
        if cents > 0 {
            title = app.nextPayoutDate.map { "\(Money.format(cents)) on its way. Lands \($0.shortDay)." } ?? "\(Money.format(cents)) on its way."
            sub = "Paid out daily by Stripe. Lands the next business day."
        } else {
            title = "Nothing on its way."
            sub = "Paid out daily. Lands the next business day."
        }
        return VStack(alignment: .leading, spacing: Space.xs) {
            Text("Pending").labelStyle()
            Text(title).font(HDFont.body).foregroundStyle(Palette.ink)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            Text(sub).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
        }
        .padding(.bottom, Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
        .accessibilityElement(children: .combine)
    }

    // MARK: Breakdown

    private var breakdown: some View {
        let services = weekBookings.reduce(0) { $0 + $1.price.servicesCents }
        let travel = weekBookings.reduce(0) { $0 + $1.price.travelFeeCents }
        let fee = weekBookings.reduce(0) { $0 + $1.price.platformFeeCents }
        let tips = weekBookings.reduce(0) { $0 + $1.price.tipCents }
        return VStack(alignment: .leading, spacing: 0) {
            Text("How it breaks down").font(HDFont.section).foregroundStyle(Palette.ink).padding(.bottom, Space.xs)
            receiptRow("Services", value: Money.format(services))
            receiptRow("Travel fees", value: Money.format(travel))
            receiptRow("Hair Done's 12%", value: "−" + Money.format(fee), soft: true)
            receiptRow("Tips", sub: "All yours, no fee.", value: "+" + Money.format(tips))
            HStack(alignment: .firstTextBaseline) {
                Text("To you").font(HDFont.bodyStrong).foregroundStyle(Palette.ink)
                Spacer()
                Text(Money.format(thisWeek)).font(HDFont.priceTotal).foregroundStyle(Palette.ink)
            }
            .padding(.top, Space.m)
            .accessibilityElement(children: .combine)
            Text("The 12% comes off services and travel. The $3 booking fee is paid by the client, not you.")
                .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.s)
        }
    }

    private func receiptRow(_ label: String, sub: String? = nil, value: String, soft: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(HDFont.body).foregroundStyle(Palette.ink)
                if let sub { Text(sub).font(HDFont.caption).foregroundStyle(Palette.inkSoft) }
            }
            Spacer()
            Text(value).font(HDFont.price).foregroundStyle(soft ? Palette.inkSoft : Palette.ink)
        }
        .padding(.vertical, Space.m)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
        .accessibilityElement(children: .combine)
    }

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "History")
            ForEach(history) { payout in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(payout.date.longDate).font(HDFont.body).foregroundStyle(Palette.ink)
                            HStack(spacing: 6) {
                                Circle().fill(payout.status == .paid ? Palette.success : Palette.warn).frame(width: 6, height: 6)
                                Text(payout.status == .paid ? "Paid out \(ProFlow.inSentence(payout.date))" : "Paying out \(ProFlow.inSentence(payout.date))")
                                    .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                            }
                        }
                        Spacer()
                        Text(Money.format(payout.amountCents)).font(HDFont.price).foregroundStyle(Palette.ink)
                    }
                    .padding(.vertical, Space.m)
                    .accessibilityElement(children: .combine)
                    let rows = payout.bookingIDs.compactMap { id in app.proBookings.first { $0.id == id } }
                    ForEach(rows) { b in
                        NavigationLink(value: Route.proBooking(b.id)) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    if app.isClientNameKnown(b.clientID) {
                                        Text("\(app.clientName(b.clientID)) · \(b.servicesLine)").font(HDFont.sub).foregroundStyle(Palette.ink).lineLimit(1)
                                    } else {
                                        HStack(spacing: Space.s) {
                                            SkeletonBlock(width: 64, height: 14)
                                            Text(b.servicesLine).font(HDFont.sub).foregroundStyle(Palette.ink).lineLimit(1)
                                        }
                                    }
                                    Text(b.price.tipCents > 0 ? "\(b.start.friendlyDay) · tip \(Money.format(b.price.tipCents))" : b.start.friendlyDay)
                                        .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                                }
                                Spacer()
                                Text(Money.format(b.price.proPayoutCents)).font(HDFont.priceSmall).foregroundStyle(Palette.inkSoft)
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .regular)).foregroundStyle(Palette.inkFaint)
                            }
                            .padding(.leading, Space.l)
                            .padding(.vertical, Space.s)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityHint("Opens the booking")
                    }
                }
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
            }
        }
    }
}

/// Where the money goes. Stripe Express, set up once.
struct PayoutDetailsSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var fetching = false

    private var connected: Bool { app.proSelf?.payoutsConnected ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Payouts", onClose: { dismiss() })
            VStack(alignment: .leading, spacing: Space.l) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(connected ? "On." : "Not set up yet.").font(HDFont.name).foregroundStyle(Palette.ink)
                    Text(connected
                         ? "Daily, to your bank, through Stripe. Each payout lands the next business day."
                         : "Payouts go to your bank daily through Stripe. About two minutes to set up. Clients can't book you until it's done.")
                        .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if connected {
                    OutlineButton(title: "Manage payouts in Stripe", symbol: "arrow.up.right", isLoading: fetching, isEnabled: !app.isOffline) {
                        Task { await open() }
                    }
                } else {
                    InkButton(title: "Set up payouts", symbol: "arrow.up.right", isLoading: fetching, isEnabled: !app.isOffline) {
                        Task { await open() }
                    }
                }
                Text(app.isOffline ? "You're offline. Try again when you're back." : "Stripe holds your bank details, not us.")
                    .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
            }
            .screenGutter()
            .padding(.top, Space.s)
            .padding(.bottom, Space.xl)
            Spacer(minLength: 0)
        }
        .paperBackground()
        .holdsPushRoutes()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.paper)
        .payoutNoticeAlert()
    }

    private func open() async {
        guard let pro = app.proSelf else { return }
        fetching = true
        defer { fetching = false }
        guard let url = await app.payoutLink() else { return }
        openURL(url) { accepted in
            if !accepted { Task { @MainActor in app.payoutNotice = .didntOpen } }
        }
        // The real answer comes back from Stripe (AppState.payoutsReturned); the sample data says yes now.
        if !connected && !app.isLive {
            var updated = pro
            updated.payoutsConnected = true
            if await app.saveProSelf(updated) { app.show("Payouts on. Daily, to your bank.") }
        }
    }
}

/// What `AppState.payoutNotice` says, on a short paper sheet (no system alert). The payout screens
/// (pro setup, Payouts) show it themselves; the root shows it only when neither is up.
struct PayoutNoticeAlert: ViewModifier {
    @Environment(AppState.self) private var app
    @Environment(\.openURL) private var openURL
    var isFallback: Bool

    private var isShown: Binding<Bool> {
        Binding(
            get: { app.payoutNotice != nil && (!isFallback || app.payoutSurfaces == 0) },
            set: { if !$0 { app.payoutNotice = nil } }
        )
    }

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: isShown) {
                PayoutNoticeSheet()
            }
            .onAppear { if !isFallback { app.payoutSurfaces += 1 } }
            .onDisappear { if !isFallback { app.payoutSurfaces = max(0, app.payoutSurfaces - 1) } }
    }
}

private struct PayoutNoticeSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.openURL) private var openURL
    /// Kept so the words don't vanish while the sheet slides away.
    @State private var notice: PayoutNotice? = nil

    private var title: String {
        switch notice ?? app.payoutNotice {
        case .didntOpen: return "Stripe didn't open."
        case .stillChecking: return "Stripe's still checking."
        case .linkExpired: return "That Stripe link ran out."
        case nil: return ""
        }
    }

    private var message: String {
        switch notice ?? app.payoutNotice {
        case .didntOpen: return "Try again in a minute."
        case .stillChecking: return "It's looking over your details. This usually takes a minute, and we'll show it here when it's on."
        case .linkExpired: return "Open it again to pick up where you left off."
        case nil: return ""
        }
    }

    var body: some View {
        Group {
            if (notice ?? app.payoutNotice) == .linkExpired {
                ConfirmSheet(title: title, message: message, confirmTitle: "Open Stripe", cancelTitle: "Not now",
                             onConfirm: {
                                 app.payoutNotice = nil
                                 Task { await reopen() }
                             },
                             onCancel: { app.payoutNotice = nil }) { EmptyView() }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(HDFont.titleSmall).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(message).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.s)
                    InkButton(title: "Got it") { app.payoutNotice = nil }
                        .padding(.top, Space.xl)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.xl + Space.s)
                .padding(.bottom, Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .confirmSheetPresentation()
        .onAppear { notice = app.payoutNotice }
    }

    private func reopen() async {
        guard let url = await app.payoutLink() else { return }
        openURL(url) { accepted in
            if !accepted { Task { @MainActor in app.payoutNotice = .didntOpen } }
        }
    }
}

extension View {
    /// See `PayoutNoticeAlert`. `fallback: true` on the root only.
    func payoutNoticeAlert(fallback: Bool = false) -> some View {
        modifier(PayoutNoticeAlert(isFallback: fallback))
    }
}

#Preview("Earnings") {
    ProEarningsView().environment(previewApp(mode: .pro))
}
