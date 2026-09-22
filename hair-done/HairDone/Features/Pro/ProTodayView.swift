import SwiftUI

/// The Today tab. Her money at the top, new requests she has to answer, then the next job, big.
struct ProTodayView: View {
    @Environment(AppState.self) private var app
    @State private var declining: Booking? = nil
    @State private var accepting: String? = nil

    private var today: Date { Date() }
    private var pro: Pro? { app.proSelf }

    private var requests: [Booking] {
        app.proBookings.filter { $0.status == .requested }.sorted { $0.createdAt < $1.createdAt }
    }
    private var todays: [Booking] {
        app.proBookings.filter { $0.isToday && $0.status != .requested && !$0.status.isCancelled }.sorted { $0.start < $1.start }
    }
    /// The one she's driving to next. Something in motion wins; otherwise the first confirmed one still to come.
    private var nextJob: Booking? {
        if let active = todays.first(where: { $0.status.isActiveDay }) { return active }
        if let upcoming = todays.first(where: { $0.status == .confirmed }) { return upcoming }
        return todays.last(where: { $0.status == .done })
    }
    private var laterToday: [Booking] {
        guard let next = nextJob else { return todays.filter { $0.status.isUpcoming } }
        return todays.filter { $0.id != next.id && $0.status.isUpcoming && $0.start >= next.start }
    }
    private var doneToday: [Booking] {
        todays.filter { $0.status.isFinished && $0.id != nextJob?.id }
    }
    private var tomorrow: [Booking] {
        app.proBookings.filter { Calendar.current.isDateInTomorrow($0.start) && $0.status.isUpcoming && $0.status != .requested }
            .sorted { $0.start < $1.start }
    }

    private var earnedToday: Int { ProMoney.payout(app.proBookings, on: today) }
    private var earnedWeek: Int { ProMoney.payout(app.proBookings, weekOf: ProWeek.monday(of: today)) }
    private var pending: Payout? { app.payouts.first { $0.status == .pending } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    header
                    earningsTiles
                    requestsSection
                    nextSection
                    if !laterToday.isEmpty { list("Later today", laterToday) }
                    if !doneToday.isEmpty { list("Done today", doneToday) }
                    tomorrowSection
                }
                .screenGutter()
                .padding(.top, Space.s)
                .padding(.bottom, Space.section)
            }
            .paperBackground()
            .refreshable { await app.loadProSide() }
            .toolbar(.hidden, for: .navigationBar)
            .hdDestinations()
            .sheet(item: $declining) { b in
                DeclineSheet(booking: b, clientName: app.clientName(b.clientID))
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today").font(HDFont.hero).foregroundStyle(Palette.ink)
                Text(today.shortDay).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                if let pro {
                    Text(ProFlow.greeting(for: pro.firstName)).font(HDFont.body).foregroundStyle(Palette.ink).padding(.top, 2)
                    if pro.reliabilityScore < 1 {
                        Text("\(Int((pro.reliabilityScore * 100).rounded()))% of bookings kept")
                            .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    }
                }
                TertiaryButton(title: "Back to booking", tint: Palette.lacquer) { app.switchMode(.client) }
                    .padding(.leading, -8)
            }
            Spacer()
            NavigationLink(value: Route.proProfileEdit) { IconGlyph(symbol: "gearshape") }
                .buttonStyle(PressLift(scale: 0.92))
                .accessibilityLabel("Edit your profile")
        }
    }

    // MARK: Earnings

    private var earningsTiles: some View {
        HStack(spacing: Space.s) {
            tile("Today", earnedToday, sub: nil)
            tile("This week", earnedWeek, sub: nil)
            tile("Pending", pending?.amountCents ?? 0, sub: pending.map { "\($0.bookingIDs.count) to pay out" } ?? "Nothing waiting")
        }
    }

    private func tile(_ label: String, _ cents: Int, sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).labelStyle()
            Text(Money.format(cents)).font(HDFont.priceLarge).foregroundStyle(Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            if let sub { Text(sub).font(HDFont.caption).foregroundStyle(Palette.inkSoft).lineLimit(1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: Space.m)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(Money.format(cents))\(sub.map { ", \($0)" } ?? "")")
    }

    // MARK: Requests

    @ViewBuilder
    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: requests.isEmpty ? "New requests" : "New requests · \(requests.count)")
            if requests.isEmpty {
                Text("No new requests. Your profile's live.")
                    .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            } else {
                ForEach(requests) { b in requestCard(b) }
            }
        }
    }

    private func requestCard(_ b: Booking) -> some View {
        let client = app.clientName(b.clientID)
        return VStack(alignment: .leading, spacing: Space.m) {
            NavigationLink(value: Route.proBooking(b.id)) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(client) wants \(b.servicesLine)").font(HDFont.heading).foregroundStyle(Palette.ink)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                    }
                    Text("\(b.start.friendlyDayTime) · \(b.address.suburb)").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    if !b.notes.isEmpty {
                        Text("“\(b.notes)”").font(HDFont.sub).foregroundStyle(Palette.ink).italic().lineLimit(3).padding(.top, 2)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(Money.format(b.price.proPayoutCents)).font(HDFont.priceLarge).foregroundStyle(Palette.ink)
                        Text("to you, after the 12%").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    }
                    .padding(.top, 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the request")

            HStack(spacing: Space.s) {
                PrimaryButton(title: "Accept", isLoading: accepting == b.id) { Task { await accept(b) } }
                    .frame(maxWidth: 160)
                SecondaryButton(title: "Decline") { declining = b }
                    .frame(maxWidth: 140)
                Spacer(minLength: 0)
            }
            Text(ProFlow.autoDeclineLine(for: b)).font(HDFont.caption).foregroundStyle(Palette.warn)
        }
        .card()
    }

    private func accept(_ b: Booking) async {
        accepting = b.id
        defer { accepting = nil }
        if await app.update(b, to: .confirmed) != nil {
            Haptics.success()
            app.show("Confirmed. She's been told.")
        }
    }

    // MARK: Next up

    @ViewBuilder
    private var nextSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: "Next up")
            if let b = nextJob {
                nextCard(b)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nothing on today.").font(HDFont.heading).foregroundStyle(Palette.ink)
                    Text(tomorrow.isEmpty ? "Nothing tomorrow either. Check Calendar's got you on."
                                          : "Tomorrow: \(tomorrow.count == 1 ? "1 booking" : "\(tomorrow.count) bookings").")
                        .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
        }
    }

    private func nextCard(_ b: Booking) -> some View {
        let client = app.clientName(b.clientID)
        return VStack(alignment: .leading, spacing: Space.l) {
            NavigationLink(value: Route.proBooking(b.id)) {
                VStack(alignment: .leading, spacing: Space.m) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(b.start.clock).font(HDFont.hero).foregroundStyle(Palette.ink).monospacedDigit()
                            Text("\(b.minutes.minutesLabel) · \(b.servicesLine)").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        }
                        Spacer()
                        StatusBadge(status: b.status)
                    }
                    Hairline()
                    HStack(spacing: Space.m) {
                        Avatar(name: client, seed: ProFlow.seed(for: b.clientID), size: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(client).font(HDFont.bodyStrong).foregroundStyle(Palette.ink)
                            Text(b.address.full).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                            if !b.address.instructions.isEmpty {
                                Text(b.address.instructions).font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                    }
                    if !b.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Her notes").labelStyle()
                            Text(b.notes).font(HDFont.sub).foregroundStyle(Palette.ink)
                        }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(Money.format(b.price.proPayoutCents)).font(HDFont.price).foregroundStyle(Palette.ink)
                        Text("to you").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the booking")
            StatusActionButton(booking: b, clientName: client)
        }
        .card()
    }

    // MARK: Lists

    private func list(_ title: String, _ items: [Booking]) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            SectionHeader(title: title)
            ForEach(items) { b in
                NavigationLink(value: Route.proBooking(b.id)) {
                    ProBookingRow(booking: b, clientName: app.clientName(b.clientID))
                }
                .buttonStyle(.plain)
                if b.id != items.last?.id { Hairline() }
            }
        }
    }

    @ViewBuilder
    private var tomorrowSection: some View {
        if tomorrow.isEmpty {
            if nextJob != nil {
                VStack(alignment: .leading, spacing: Space.xs) {
                    SectionHeader(title: "Tomorrow")
                    Text("Free all day.").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                }
            }
        } else {
            list("Tomorrow", tomorrow)
        }
    }
}

#Preview("Today") {
    ProTodayView().environment(previewApp(mode: .pro))
}
