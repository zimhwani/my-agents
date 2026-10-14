import SwiftUI
import MapKit

/// The Today tab. What's next, big and in ink; what's waiting; what she's made.
/// While she isn't live, a checklist says what's left. While a request is open, it looks again every minute.
struct ProTodayView: View {
    @Environment(AppState.self) private var app
    @State private var declining: Booking? = nil
    @State private var accepting: String? = nil
    @State private var path = NavigationPath()
    @State private var askForPush = false
    @State private var showPayouts = false
    @State private var showIDCheck = false
    @State private var resuming = false

    private enum Destination: Hashable { case hours }

    private var today: Date { Date() }
    private var pro: Pro? { app.proSelf }

    private var requests: [Booking] { app.openRequests }
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
    /// A status button is live on the next job, so Accept steps back to the quieter style.
    private var statusIsLive: Bool { nextJob.map { ProFlow.nextStep(for: $0.status) != nil } ?? false }

    private var earnedToday: Int { ProMoney.payout(app.proBookings, on: today) }
    private var earnedWeek: Int { ProMoney.payout(app.proBookings, weekOf: ProWeek.monday(of: today)) }

    // MARK: Live or not

    private struct Check {
        let title: String
        let subtitle: String
        let isDone: Bool
        let action: () -> Void
    }

    private var checks: [Check] {
        guard let pro else { return [] }
        return [
            Check(title: "Payouts", subtitle: "So your money has somewhere to land.", isDone: pro.payoutsConnected) { showPayouts = true },
            Check(title: "ID check (we do this)", subtitle: pro.idSubmitted || pro.isVerified ? "Sent. A person checks it, usually within a day." : "Photo ID and a selfie.",
                  isDone: pro.idSubmitted || pro.isVerified) { showIDCheck = true },
            Check(title: "Three photos", subtitle: "Of your own work. It's what gets you booked.", isDone: pro.work.count >= 3) { path.append(Route.proWork) },
            Check(title: "Your hours", subtitle: "When clients can book you.", isDone: pro.availability.hours.values.contains { !$0.isEmpty }) { path.append(Destination.hours) }
        ]
    }

    /// Clients can find and book her: the same test the server uses.
    private var isLive: Bool {
        guard let pro else { return false }
        return pro.isActive && pro.isVerified && pro.payoutsConnected && pro.isOnboarded && !pro.isClosed
    }
    private var isPaused: Bool { pro.map { !$0.isActive && !$0.isClosed } ?? false }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if app.isOffline { OfflineBar().padding(.horizontal, -Space.gutter) }
                    header.padding(.top, Space.s)
                    if app.proSideLoadFailed && app.proBookings.isEmpty {
                        ErrorState { Task { await app.loadProSide() } }
                            .padding(.horizontal, -Space.gutter)
                    } else {
                        VStack(alignment: .leading, spacing: Space.section) {
                            if isPaused { pausedBlock }
                            if !isLive && !isPaused && !checks.isEmpty { notLiveBlock }
                            nextSection
                            moneyFacts
                            requestsSection
                            if !laterToday.isEmpty { list("Later today", laterToday) }
                            if !doneToday.isEmpty { list("Done today", doneToday) }
                            tomorrowSection
                        }
                        .padding(.top, Space.xl)
                    }
                }
                .screenGutter()
                .padding(.bottom, Space.section)
            }
            .paperBackground()
            .refreshable { await app.loadProSide() }
            .toolbar(.hidden, for: .navigationBar)
            .hdDestinations()
            .navigationDestination(for: Destination.self) { d in
                switch d {
                case .hours: ProHoursScreen()
                }
            }
            .sheet(item: $declining) { b in
                DeclineSheet(booking: b, clientName: app.clientName(b.clientID))
            }
            .sheet(isPresented: $askForPush) { PushPrePrompt(side: .pro) }
            .sheet(isPresented: $showPayouts) { PayoutDetailsSheet() }
            .sheet(isPresented: $showIDCheck) { ProIDCheckSheet() }
            .proSideBanner()
        }
        .receivesPendingRoutes($path) { $0.isProBooking }
        // Her first time on Today (straight after pro setup, usually): ask about notifications,
        // because requests lapse if she doesn't see them.
        .task {
            guard await app.shouldAskForPush(.pro) else { return }
            try? await Task.sleep(for: .seconds(0.8))
            askForPush = true
        }
        // Until push is everywhere: while Today's on screen and a request is open, look again every minute.
        .task(id: requests.isEmpty) {
            guard !requests.isEmpty else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled, !app.openRequests.isEmpty, !app.isOffline else { continue }
                await app.loadProSide(people: true)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: Space.m) {
            VStack(alignment: .leading, spacing: Space.xs) {
                ProEyebrow(name: pro?.displayName ?? "You")
                (Text("\(ProFlow.greetingLead()), ") + Text(pro?.firstName ?? "you").italic() + Text("."))
                    .font(HDFont.display)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(dayLine).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                if let pro, pro.reliabilityScore < 1 {
                    Text("\(Int((pro.reliabilityScore * 100).rounded()))% of bookings kept")
                        .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer(minLength: 0)
            Button {
                Haptics.light()
                app.selectedProTab = .profile
            } label: {
                ProFacePhoto(pro: pro)
                    .frame(width: 32, height: 40)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressLift(scale: 0.94))
            .accessibilityLabel("Your profile")
        }
    }

    private var dayLine: String {
        let jobs = todays.filter { !$0.status.isCancelled }
        guard !jobs.isEmpty else { return "\(ProFlow.longDay(today)) · Nothing on today." }
        let booked = jobs.reduce(0) { $0 + $1.price.proPayoutCents }
        return "\(ProFlow.longDay(today)) · \(ProFlow.count(jobs.count, "job", "jobs")) · \(Money.format(booked)) booked"
    }

    // MARK: Paused, not live

    private var pausedBlock: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Paused.").font(HDFont.titleSmall).foregroundStyle(Palette.ink)
            Text("Clients can't find you. Jobs you've got still stand.")
                .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            OutlineButton(title: "Start taking bookings", isLoading: resuming, isEnabled: !app.isOffline, compact: true) {
                Task { await resume() }
            }
            .fixedSize()
            .padding(.top, Space.xs)
        }
    }

    private func resume() async {
        guard var p = app.proSelf else { return }
        resuming = true
        defer { resuming = false }
        p.isActive = true
        if await app.saveProSelf(p) { app.show("You're taking bookings again.") }
    }

    private var notLiveBlock: some View {
        let done = checks.filter(\.isDone).count
        let allIn = done == checks.count
        return VStack(alignment: .leading, spacing: 0) {
            Text("You're not live yet.").font(HDFont.titleSmall).foregroundStyle(Palette.ink)
            Text(allIn ? "All four done. We're checking your ID, usually within a day. Then clients can book you."
                       : "\(done) of \(checks.count) done.")
                .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.xs)
                .padding(.bottom, Space.s)
            ForEach(Array(checks.enumerated()), id: \.offset) { _, c in
                ChecklistRow(title: c.title, subtitle: c.subtitle, isDone: c.isDone, action: c.action)
            }
        }
    }

    // MARK: Next up

    @ViewBuilder
    private var nextSection: some View {
        if let b = nextJob {
            nextHero(b)
        } else {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Next up").labelStyle()
                Text("Nothing on today.").font(HDFont.titleSmall).foregroundStyle(Palette.ink)
                Text(tomorrow.isEmpty ? "Nothing tomorrow either. Check Calendar's got you on."
                                      : "Tomorrow: \(ProFlow.count(tomorrow.count, "booking", "bookings")).")
                    .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            }
        }
    }

    /// The ink block: the time big, who and what, where, then the one action.
    private func nextHero(_ b: Booking) -> some View {
        let client = app.clientName(b.clientID)
        return VStack(alignment: .leading, spacing: Space.l) {
            NavigationLink(value: Route.proBooking(b.id)) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(spacing: Space.s) {
                        Text("Next up").eyebrowStyle(color: Palette.onInkSoft)
                        Text("·").eyebrowStyle(color: Palette.onInkSoft)
                        Text(b.status.proLabel).eyebrowStyle(color: Palette.onInk)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Palette.onInkSoft)
                    }
                    Text(b.start.clock)
                        .font(HDFont.timeDisplay)
                        .foregroundStyle(Palette.onInk)
                        .padding(.top, Space.xs)
                    Text("\(client) · \(b.servicesLine)")
                        .font(HDFont.serif(24, relativeTo: .title2))
                        .foregroundStyle(Palette.onInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(b.address.full)
                        .font(HDFont.sub).foregroundStyle(Palette.onInkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if !b.address.instructions.isEmpty {
                        Text(b.address.instructions).font(HDFont.caption).foregroundStyle(Palette.onInkSoft)
                    }
                    Text("\(Money.format(b.price.proPayoutCents)) to you · \(b.minutes.minutesLabel)")
                        .font(HDFont.priceSmall).foregroundStyle(Palette.onInkSoft)
                        .padding(.top, Space.xs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens the booking")

            StatusActionButton(booking: b, clientName: client, onInk: true)

            if b.status == .confirmed || b.status == .onHerWay {
                Button {
                    Haptics.light()
                    openDirections(to: b.address)
                } label: {
                    Text("Directions").font(HDFont.subMedium).foregroundStyle(Palette.onInk)
                        .underline()
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens Maps")
            }
        }
        .inkBlock(padding: Space.xl)
    }

    private func openDirections(to address: Address) {
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: address.latitude, longitude: address.longitude))
        let item = MKMapItem(placemark: placemark)
        item.name = address.short
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    // MARK: Money

    @Environment(\.dynamicTypeSize) private var typeSize

    private var moneyFacts: some View {
        let facts: [(String, Int)] = [("Today", earnedToday), ("This week", earnedWeek), ("Pending", app.pendingEarningsCents)]
        return Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 0) {
                    ForEach(Array(facts.enumerated()), id: \.offset) { _, f in
                        HStack(alignment: .firstTextBaseline) {
                            Text(f.0).labelStyle()
                            Spacer()
                            Text(Money.format(f.1)).font(HDFont.priceLarge).foregroundStyle(Palette.ink)
                        }
                        .padding(.vertical, Space.s)
                        .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
                        .accessibilityElement(children: .combine)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(facts.enumerated()), id: \.offset) { i, f in
                        if i > 0 { Rectangle().fill(Palette.lineStrong).frame(width: 0.5).padding(.horizontal, Space.m) }
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text(f.0).labelStyle()
                            Text(Money.format(f.1)).font(HDFont.priceLarge).foregroundStyle(Palette.ink)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { app.selectedProTab = .earnings }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens Earnings")
    }

    // MARK: Requests

    @ViewBuilder
    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: requests.isEmpty ? "New requests" : "New requests · \(requests.count)")
            if requests.isEmpty {
                Text(emptyRequestsLine)
                    .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.xs)
            } else {
                ForEach(requests) { b in requestRow(b) }
            }
        }
    }

    private var emptyRequestsLine: String {
        if isLive { return "No new requests. Your profile's live." }
        if isPaused { return "No new requests. You're paused, so nobody can send one." }
        return "No requests yet. They start once you're live."
    }

    private func requestRow(_ b: Booking) -> some View {
        let client = app.clientName(b.clientID)
        return VStack(alignment: .leading, spacing: Space.m) {
            NavigationLink(value: Route.proBooking(b.id)) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(ProFlow.replyBy(b)).labelStyle()
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(client) wants \(b.servicesLine)").font(HDFont.name).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: Space.s)
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .regular)).foregroundStyle(Palette.inkFaint)
                    }
                    Text("\(b.start.friendlyDayTime) · \(b.address.suburb)").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    if !b.notes.isEmpty {
                        Text("“\(b.notes)”").font(HDFont.serif(17, relativeTo: .body).italic()).foregroundStyle(Palette.ink)
                            .lineLimit(3).padding(.top, 2)
                    }
                    Text("\(Money.format(b.price.proPayoutCents)) to you").font(HDFont.price).foregroundStyle(Palette.ink)
                        .padding(.top, 2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens the request")

            HStack(spacing: Space.s) {
                if statusIsLive {
                    OutlineButton(title: "Accept", isLoading: accepting == b.id, isEnabled: !app.isOffline, compact: true) { Task { await accept(b) } }
                } else {
                    InkButton(title: "Accept", isLoading: accepting == b.id, isEnabled: !app.isOffline, compact: true) { Task { await accept(b) } }
                }
                OutlineButton(title: "Decline", isEnabled: !app.isOffline, compact: true) { declining = b }
            }
            WarnDotLine(text: "\(ProFlow.timeLeft(b)). After that it lapses and counts against you.", font: HDFont.caption)
        }
        .padding(.vertical, Space.l)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
    }

    private func accept(_ b: Booking) async {
        accepting = b.id
        defer { accepting = nil }
        if await app.update(b, to: .confirmed) != nil {
            Haptics.success()
            app.show("Booked. \(app.clientName(b.clientID))'s \(b.start.friendlyDay) at \(b.start.clock).")
        }
    }

    // MARK: Lists

    private func list(_ title: String, _ items: [Booking]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: title)
            ForEach(items) { b in
                NavigationLink(value: Route.proBooking(b.id)) {
                    ProBookingRow(booking: b, clientName: app.clientName(b.clientID))
                }
                .buttonStyle(.plain)
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

/// The ID check from Today's checklist, as a sheet.
struct ProIDCheckSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "ID check", subtitle: "Clients only book pros a person has checked.", onClose: { dismiss() })
            ScrollView {
                ProIDCheckView()
                    .screenGutter()
                    .padding(.vertical, Space.l)
            }
        }
        .paperBackground()
        .holdsPushRoutes()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.paper)
    }
}

#Preview("Today") {
    ProTodayView().environment(previewApp(mode: .pro))
}
