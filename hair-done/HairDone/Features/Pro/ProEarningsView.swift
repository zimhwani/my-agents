import SwiftUI

/// Her money. This week big, seven bars, what's pending, what's landed, and how the fee works.
struct ProEarningsView: View {
    @Environment(AppState.self) private var app
    @State private var showPayoutDetails = false

    private var monday: Date { ProWeek.monday(of: Date()) }
    private var thisWeek: Int { ProMoney.payout(app.proBookings, weekOf: monday) }
    private var lastWeek: Int { ProMoney.payout(app.proBookings, weekOf: monday.adding(days: -7)) }
    private var weekBookings: [Booking] {
        ProMoney.earning(app.proBookings).filter { ProWeek.contains($0.start, weekOf: monday) }
    }
    private var days: [(day: Date, cents: Int)] {
        ProWeek.days(from: monday).map { ($0, ProMoney.payout(app.proBookings, on: $0)) }
    }
    private var pending: Payout? { app.payouts.first { $0.status == .pending } }
    private var history: [Payout] { app.payouts.sorted { $0.date > $1.date } }
    private var nothingYet: Bool { ProMoney.earning(app.proBookings).isEmpty && app.payouts.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    Text("Earnings").font(HDFont.hero).foregroundStyle(Palette.ink)
                    if nothingYet {
                        EmptyState(symbol: "dollarsign.circle", title: "Nothing yet.", message: "It'll be here the day after your first booking.")
                    } else {
                        weekCard
                        pendingCard
                        breakdownCard
                        historySection
                    }
                    NavRow(symbol: "building.columns", title: "Payout details", value: app.proSelf?.payoutsConnected == true ? "On" : "Not set up") {
                        showPayoutDetails = true
                    }
                    .card(padding: Space.s)
                }
                .screenGutter()
                .padding(.top, Space.s)
                .padding(.bottom, Space.section)
            }
            .paperBackground()
            .refreshable { await app.loadProSide() }
            .toolbar(.hidden, for: .navigationBar)
            .hdDestinations()
            .sheet(isPresented: $showPayoutDetails) { PayoutDetailsSheet() }
        }
    }

    // MARK: This week

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            VStack(alignment: .leading, spacing: 4) {
                Text("This week").labelStyle()
                Text(Money.format(thisWeek)).font(HDFont.hero).foregroundStyle(Palette.ink).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(weekLine).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            }
            .accessibilityElement(children: .combine)
            bars
        }
        .card()
    }

    private var weekLine: String {
        let count = weekBookings.count == 1 ? "1 booking" : "\(weekBookings.count) bookings"
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
                let h = max(CGFloat(entry.cents) / CGFloat(maxCents) * height, entry.cents > 0 ? 6 : 0)
                VStack(spacing: 6) {
                    ZStack(alignment: .bottom) {
                        Rectangle().fill(Palette.lacquerSoft).frame(height: height)
                        Rectangle().fill(Palette.lacquer).frame(height: h)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text(entry.day.weekday.short.prefix(1))
                        .font(HDFont.caption)
                        .foregroundStyle(isToday ? Palette.lacquer : Palette.inkSoft)
                        .fontWeight(isToday ? .semibold : .regular)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(entry.day.weekday.long), \(Money.format(entry.cents))")
            }
        }
        .animation(Motion.spring, value: days.map(\.cents))
    }

    // MARK: Pending

    private var pendingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pending").labelStyle()
            if let pending {
                Text(Money.format(pending.amountCents)).font(HDFont.priceLarge).foregroundStyle(Palette.ink)
                Text("Arrives \(ProFlow.inSentence(pending.date)). Daily payouts by Stripe.")
                    .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            } else {
                Text("Nothing waiting").font(HDFont.heading).foregroundStyle(Palette.ink)
                Text("Paid out daily. Lands the next business day.").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .combine)
    }

    // MARK: Breakdown

    private var breakdownCard: some View {
        let services = weekBookings.reduce(0) { $0 + $1.price.servicesCents }
        let travel = weekBookings.reduce(0) { $0 + $1.price.travelFeeCents }
        let fee = weekBookings.reduce(0) { $0 + $1.price.platformFeeCents }
        let tips = weekBookings.reduce(0) { $0 + $1.price.tipCents }
        return VStack(alignment: .leading, spacing: Space.s) {
            Text("How it breaks down").font(HDFont.heading).foregroundStyle(Palette.ink).padding(.bottom, 4)
            PriceRow(label: "Services", cents: services)
            PriceRow(label: "Travel fees", cents: travel)
            HStack {
                Text("Hair Done fee, 12%").font(HDFont.body).foregroundStyle(Palette.ink)
                Spacer()
                Text("−" + Money.format(fee)).font(HDFont.price).foregroundStyle(Palette.inkSoft)
            }
            .accessibilityElement(children: .combine)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tips").font(HDFont.body).foregroundStyle(Palette.ink)
                    Text("All yours, no fee.").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                Text("+" + Money.format(tips)).font(HDFont.price).foregroundStyle(Palette.success)
            }
            .accessibilityElement(children: .combine)
            Hairline().padding(.vertical, 4)
            PriceRow(label: "To you", cents: thisWeek, emphasis: true)
            Text("The 12% comes off services and travel. The $3 booking fee is paid by the client, not you.")
                .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
        }
        .card()
    }

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: "History")
            if history.isEmpty {
                Text("No payouts yet.").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            }
            ForEach(history) { payout in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(payout.date.longDate).font(HDFont.bodyStrong).foregroundStyle(Palette.ink)
                            Text(payout.status == .paid ? "Paid out \(ProFlow.inSentence(payout.date))" : "Paying out \(ProFlow.inSentence(payout.date))")
                                .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                        }
                        Spacer()
                        Text(Money.format(payout.amountCents)).font(HDFont.price).foregroundStyle(Palette.ink)
                        Tag(text: payout.status == .paid ? "Paid" : "Pending",
                            color: payout.status == .paid ? Palette.success : Palette.warn,
                            background: payout.status == .paid ? Palette.successSoft : Palette.warnSoft)
                    }
                    .accessibilityElement(children: .combine)
                    let rows = payout.bookingIDs.compactMap { id in app.proBookings.first { $0.id == id } }
                    if !rows.isEmpty {
                        Hairline().padding(.top, Space.m)
                        ForEach(rows) { b in
                            NavigationLink(value: Route.proBooking(b.id)) {
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(app.clientName(b.clientID)) · \(b.servicesLine)").font(HDFont.sub).foregroundStyle(Palette.ink).lineLimit(1)
                                        HStack(spacing: 6) {
                                            Text(b.start.friendlyDay).font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                                            if b.price.tipCents > 0 {
                                                Text("Tip \(Money.format(b.price.tipCents))").font(HDFont.caption).foregroundStyle(Palette.success)
                                            }
                                        }
                                    }
                                    Spacer()
                                    Text(Money.format(b.price.proPayoutCents)).font(HDFont.sub).foregroundStyle(Palette.inkSoft).monospacedDigit()
                                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                                }
                                .padding(.vertical, Space.s)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityHint("Opens the booking")
                        }
                    }
                }
                .card()
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
        VStack(spacing: 0) {
            SheetHeader(title: "Payout details", onClose: { dismiss() })
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    HStack(spacing: 8) {
                        Image(systemName: connected ? "checkmark.seal.fill" : "building.columns")
                            .foregroundStyle(connected ? Palette.success : Palette.inkSoft)
                        Text(connected ? "Payouts on" : "Not set up yet").font(HDFont.heading).foregroundStyle(Palette.ink)
                    }
                    Text(connected
                         ? "Daily, to your bank, through Stripe. Each payout lands the next business day."
                         : "Payouts go to your bank daily through Stripe. About two minutes to set up. You'll need this before your first payout lands.")
                        .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                PrimaryButton(title: connected ? "Manage payouts in Stripe" : "Set up payouts", symbol: "arrow.up.right", isLoading: fetching) {
                    Task { await open() }
                }
                Text("Stripe holds your bank details, not us.").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                Spacer()
            }
            .screenGutter()
            .padding(.vertical, Space.l)
        }
        .paperBackground()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func open() async {
        guard let pro = app.proSelf else { return }
        fetching = true
        defer { fetching = false }
        do {
            let url = try await app.payments.payoutOnboardingURL(proID: pro.id)
            openURL(url)
            if !connected {
                var updated = pro
                updated.payoutsConnected = true
                await app.saveProSelf(updated)
                app.show("Payouts on. Daily, to your bank.")
            }
        } catch {
            app.show("That didn't work. Try again.")
        }
    }
}

#Preview("Earnings") {
    ProEarningsView().environment(previewApp(mode: .pro))
}
