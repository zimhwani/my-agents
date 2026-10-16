import SwiftUI
import MapKit

/// The Today tab (docs/design/pro-today-proposal.md). It answers one question in each state.
/// Busy (a job or a request today): what do I do next? A request first, since it lapses without her,
/// then the next job as the one ink block, then the rest of the day as quiet rows. Quiet: how do I get
/// booked? Her open hours as something she has, a few things that help, and her record.
/// Both end with the next seven days and the money on its way. While she isn't live, a checklist
/// says what's left. While a request is open, it looks again every minute.
struct ProTodayView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var declining: Booking? = nil
    @State private var accepting: String? = nil
    @State private var askForPush = false
    @State private var showPayouts = false
    @State private var showIDCheck = false
    @State private var showAllReviews = false
    @State private var resuming = false
    @State private var savingInstant = false
    /// She's shared her profile from here before, so the row's retired. Read when Today appears.
    @State private var hasShared = false

    private enum Destination: Hashable { case hours }

    /// The work photo count the nudge aims for (the founder's call; three is what goes live).
    private static let workTarget = 8

    private var today: Date { Date() }
    private var pro: Pro? { app.proSelf }
    /// Kept in `AppState`, so switching to booking and back lands on the same screen.
    private var path: Binding<NavigationPath> { app.path(for: ProTab.today) }

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
    /// A job or a request today. Otherwise the quiet day, about getting booked.
    private var isBusy: Bool { !todays.isEmpty || !requests.isEmpty }

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
            Check(title: "Three photos", subtitle: "Of your own work. It's what gets you booked.", isDone: pro.work.count >= 3) { path.wrappedValue.append(Route.proWork) },
            Check(title: "Your hours", subtitle: "When clients can book you.", isDone: pro.availability.hours.values.contains { !$0.isEmpty }) { path.wrappedValue.append(Destination.hours) }
        ]
    }

    /// Clients can find and book her: the same test the server uses.
    private var isLive: Bool {
        guard let pro else { return false }
        return pro.isActive && pro.isVerified && pro.payoutsConnected && pro.isOnboarded && !pro.isClosed
    }
    private var isPaused: Bool { pro.map { !$0.isActive && !$0.isClosed } ?? false }

    var body: some View {
        NavigationStack(path: path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if app.isOffline { OfflineBar().padding(.horizontal, -Space.gutter) }
                    header.padding(.top, Space.s)
                    if app.proSideLoadFailed && app.proBookings.isEmpty {
                        ErrorState { Task { await app.loadProSide() } }
                            .padding(.horizontal, -Space.gutter)
                    } else if app.showsProSideSkeleton {
                        // Before the first load: not "Nothing booked today" or the not-live list yet.
                        loadingBlock.padding(.top, Space.xl)
                    } else {
                        VStack(alignment: .leading, spacing: Space.section) {
                            if isPaused { pausedBlock }
                            if !isLive && !isPaused && !checks.isEmpty { notLiveBlock }
                            if !requests.isEmpty { requestsSection }
                            if isBusy {
                                if let b = nextJob { nextHero(b) }
                                if !laterToday.isEmpty || !doneToday.isEmpty { dayLists }
                                weekStrip
                            } else {
                                weekStrip
                                getBooked
                                record
                            }
                            moneyRow
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
                case .hours: ProHoursScreen().tabBarRoom()
                }
            }
            .sheet(item: $declining) { b in
                DeclineSheet(booking: b, clientName: app.clientName(b.clientID))
            }
            .sheet(isPresented: $askForPush) { PushPrePrompt(side: .pro) }
            .sheet(isPresented: $showPayouts) { PayoutDetailsSheet() }
            .sheet(isPresented: $showIDCheck) { ProIDCheckSheet() }
            .sheet(isPresented: $showAllReviews) {
                if let pro { ProfileAllReviewsSheet(pro: pro) }
            }
            .proSideBanner()
        }
        .receivesPendingRoutes(path) { $0.isProBooking }
        // Her first time on Today (straight after pro setup, usually): ask about notifications,
        // because requests lapse if she doesn't see them.
        .task {
            guard await app.shouldAskForPush(.pro) else { return }
            try? await Task.sleep(for: .seconds(0.8))
            askForPush = true
        }
        // Each time Today appears (and once her profile's in), whether she's shared it from here.
        .task(id: pro?.id) {
            guard let id = pro?.id else { return }
            hasShared = UserDefaults.standard.bool(forKey: Self.sharedKey(id))
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
                    .fixedSize(horizontal: false, vertical: true)
                // A quiet day has her record lower down; a busy one keeps the one line here.
                if let pro, pro.reliabilityScore < 1, isBusy {
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

    /// "Friday 16 October · 4 jobs · $334.40 to you", or "Friday 16 October · Nothing booked today."
    private var dayLine: String {
        if app.showsProSideSkeleton { return ProFlow.longDay(today) }
        guard !todays.isEmpty else { return "\(ProFlow.longDay(today)) · Nothing booked today." }
        let toYou = todays.reduce(0) { $0 + $1.price.proPayoutCents }
        return "\(ProFlow.longDay(today)) · \(ProFlow.count(todays.count, "job", "jobs")) · \(Money.format(toYou)) to you"
    }

    // MARK: Loading

    /// The shape of Next up and a couple of rows, while her day loads for the first time.
    private var loadingBlock: some View {
        VStack(alignment: .leading, spacing: Space.section) {
            VStack(alignment: .leading, spacing: Space.m) {
                SkeletonBlock(width: 120, height: 12, color: Palette.inkLine)
                SkeletonBlock(width: 140, height: 40, color: Palette.inkLine)
                SkeletonBlock(width: 200, height: 20, color: Palette.inkLine)
                SkeletonBlock(height: 52, radius: Radius.button, color: Palette.inkLine)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .inkBlock(padding: Space.xl)
            VStack(spacing: 0) {
                RowSkeleton()
                RowSkeleton()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
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

    // MARK: Requests

    /// Every open request, the one that lapses first at the top. The countdown moves every minute.
    private var requestsSection: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: Space.xl) {
                ForEach(requests) { b in requestCard(b, now: context.date) }
            }
        }
    }

    private func requestCard(_ b: Booking, now: Date) -> some View {
        let client = app.clientName(b.clientID)
        let known = app.isClientNameKnown(b.clientID)
        let deadline = ProFlow.deadline(b)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                Text("New request").labelStyle().accessibilityAddTraits(.isHeader)
                Spacer(minLength: Space.s)
                WarnDotLine(text: ProFlow.timeLeft(b, now: now), font: HDFont.caption.weight(.medium))
            }
            // Empties as the two hours run down. Decorative: the words above carry it.
            ProgressLine(fraction: ProFlow.timeLeftFraction(b, now: now))
                .padding(.top, Space.s)
                .padding(.bottom, Space.l)

            NavigationLink(value: Route.proBooking(b.id)) {
                HStack(alignment: .top, spacing: Space.l) {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        if !known { SkeletonBlock(width: 96, height: 18) }
                        Text(known ? "\(client) wants \(b.wantsLine)" : "Wants \(b.wantsLine)")
                            .font(HDFont.name).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(b.start.friendlyDayTime) · \(b.address.suburb)").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        if !b.notes.isEmpty {
                            Text("\u{201C}\(b.notes)\u{201D}").font(HDFont.serif(17, relativeTo: .body)).foregroundStyle(Palette.ink)
                                .lineLimit(3).padding(.top, 2)
                        }
                        (Text("\(Money.format(b.price.proPayoutCents)) to you").font(HDFont.price).foregroundColor(Palette.ink)
                            + Text(" · \(b.minutes.shortDuration)").font(HDFont.priceSmall).foregroundColor(Palette.inkSoft))
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    inspo(b, limit: 1, width: 56, height: 70)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens the request")

            // Accept stays ink even while On my way is live: the request sits on paper, the job on ink.
            HStack(spacing: Space.s) {
                InkButton(title: "Accept", isLoading: accepting == b.id, isEnabled: !app.isOffline, compact: true) { Task { await accept(b) } }
                OutlineButton(title: "Decline", isEnabled: !app.isOffline, compact: true) { declining = b }
            }
            .padding(.top, Space.l)
            Text(deadline > now ? "Lapses at \(deadline.clock). A lapsed request counts against you." : "A lapsed request counts against you.")
                .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.s)
        }
        .padding(.bottom, Space.l)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
    }

    private func accept(_ b: Booking) async {
        accepting = b.id
        defer { accepting = nil }
        if await app.update(b, to: .confirmed) != nil {
            Haptics.success()
            app.show("Booked. \(ProFlow.whoLead(app.clientName(b.clientID)))'s \(b.start.friendlyDay) at \(b.start.clock).")
        }
    }

    /// Her inspo, up to `limit`: the client's photos, or the seeded stand-ins on the sample data. Nothing when there are none.
    @ViewBuilder
    private func inspo(_ b: Booking, limit: Int, width: CGFloat, height: CGFloat) -> some View {
        if !b.inspoURLs.isEmpty {
            HStack(spacing: Space.xs) {
                ForEach(Array(b.inspoURLs.prefix(limit).enumerated()), id: \.offset) { _, url in
                    AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Palette.photoGround }
                        .frame(width: width, height: height)
                        .clipped()
                        .photoShape()
                }
            }
            .accessibilityHidden(true)
        } else if !b.inspoSeeds.isEmpty && !app.isLive {
            HStack(spacing: Space.xs) {
                ForEach(Array(b.inspoSeeds.prefix(limit).enumerated()), id: \.offset) { i, seed in
                    WorkTile(item: WorkItem(id: "inspo_\(b.id)_\(i)", category: b.primaryCategory, caption: "Inspo photo \(i + 1)", seed: seed), cornerRadius: Radius.photo)
                        .frame(width: width, height: height)
                }
            }
            .accessibilityHidden(true)
        }
    }

    private func hasInspo(_ b: Booking) -> Bool { !b.inspoURLs.isEmpty || (!b.inspoSeeds.isEmpty && !app.isLive) }

    // MARK: Next up

    /// The ink block: the time big, her inspo, who and what, where, then the one action.
    private func nextHero(_ b: Booking) -> some View {
        let client = app.clientName(b.clientID)
        let known = app.isClientNameKnown(b.clientID)
        return VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: Route.proBooking(b.id)) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(alignment: .center, spacing: Space.s) {
                        // The status dot in its dark-mode value, which is the one that reads on ink.
                        Circle().fill(b.status.color).frame(width: 6, height: 6)
                            .environment(\.colorScheme, .dark)
                        Text("Next up").eyebrowStyle(color: Palette.onInkSoft)
                        Text("·").eyebrowStyle(color: Palette.onInkSoft)
                        Text(b.status.proLabel).eyebrowStyle(color: Palette.onInkSoft)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Palette.onInkSoft)
                    }
                    heroTime(b).padding(.top, Space.xs)
                    if known {
                        Text("\(client) · \(b.servicesLine)")
                            .font(HDFont.serif(24, relativeTo: .title2))
                            .foregroundStyle(Palette.onInk)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        // Her name is on its way: a shimmer where it goes, then what she's booked.
                        SkeletonBlock(width: 110, height: 22, color: Palette.inkLine)
                        Text(b.servicesLine)
                            .font(HDFont.serif(24, relativeTo: .title2))
                            .foregroundStyle(Palette.onInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(b.address.full)
                        .font(HDFont.sub).foregroundStyle(Palette.onInkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if !b.address.instructions.isEmpty {
                        Text(b.address.instructions).font(HDFont.caption).foregroundStyle(Palette.onInkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("\(b.minutes.shortDuration) · \(Money.format(b.price.proPayoutCents)) to you")
                        .font(HDFont.priceSmall).foregroundStyle(Palette.onInkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens the booking")

            // On my way opens 3 hours before; until then the button's place says when.
            StatusActionButton(booking: b, clientName: client, onInk: true)
                .padding(.top, Space.l)
            heroLinks(b, client: client)
        }
        .inkBlock(padding: Space.gutter)
    }

    /// "12:30 pm" at 56 light, the biggest thing on the screen, with up to two inspo photos beside it
    /// (under it at the accessibility sizes).
    private func heroTime(_ b: Booking) -> some View {
        let parts = b.start.clock.split(separator: " ").map(String.init)
        let time = (Text(parts.first ?? b.start.clock).font(HDFont.timeDisplay)
            + Text(parts.count > 1 ? " \(parts[1])" : "").font(HDFont.sans(22, relativeTo: .title2, weight: .light)))
            .foregroundColor(Palette.onInk)
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.s))
            : AnyLayout(HStackLayout(alignment: .bottom, spacing: Space.m))
        return layout {
            time
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
            if hasInspo(b) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    inspo(b, limit: 2, width: 38, height: 48)
                    Text("Her inspo").font(HDFont.caption).foregroundStyle(Palette.onInkSoft)
                }
                .padding(.bottom, Space.xs)
            }
        }
    }

    /// Directions and Message, as text actions on the ink.
    @ViewBuilder
    private func heroLinks(_ b: Booking, client: String) -> some View {
        let directions = b.status == .confirmed || b.status == .onHerWay
        let thread = app.thread(for: b)
        if directions || thread != nil {
            HStack(spacing: Space.xl) {
                if directions {
                    Button {
                        Haptics.light()
                        openDirections(to: b.address)
                    } label: {
                        heroLink("Directions")
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens Maps")
                }
                if let thread {
                    NavigationLink(value: Route.thread(thread.id)) {
                        heroLink("Message \(ProFlow.who(client))")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, Space.xs)
        }
    }

    private func heroLink(_ title: String) -> some View {
        Text(title).font(HDFont.subMedium).foregroundStyle(Palette.onInk)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }

    private func openDirections(to address: Address) {
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: address.latitude, longitude: address.longitude))
        let item = MKMapItem(placemark: placemark)
        item.name = address.short
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    // MARK: Later today, earlier

    /// The rest of her day as hairline rows, payout on the right. Tomorrow is in the strip and Calendar.
    private var dayLists: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            if !laterToday.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(title: "Later today")
                    rows(laterToday)
                }
            }
            if !doneToday.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Earlier").labelStyle().accessibilityAddTraits(.isHeader)
                    rows(doneToday)
                }
            }
        }
    }

    private func rows(_ items: [Booking]) -> some View {
        ForEach(items) { b in
            NavigationLink(value: Route.proBooking(b.id)) {
                ProBookingRow(booking: b, clientName: app.clientName(b.clientID), nameKnown: app.isClientNameKnown(b.clientID), showsPayout: true)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Next 7 days

    private struct StripDay: Identifiable {
        let date: Date
        let jobs: Int
        let requests: Int
        let openMinutes: Int
        /// She doesn't work that day, or she's blocked it.
        let isOff: Bool
        var id: Date { date }
        var isToday: Bool { Calendar.current.isDateInToday(date) }
        /// "5 h", "Off"
        var hoursLabel: String { isOff ? "Off" : "\(ProOpenHours.hours(openMinutes)) h" }
    }

    /// Seven days from today, not Monday to Sunday: on a Friday most of a Monday week has gone.
    private var stripDays: [StripDay] {
        ProOpenHours.nextSevenDays(from: today).map { day -> StripDay in
            let onDay = app.proBookings.filter { Calendar.current.isDate($0.start, inSameDayAs: day) && !$0.status.isCancelled }
            let open = pro.map { ProOpenHours.minutes(on: day, pro: $0, bookings: app.proBookings, now: today) } ?? 0
            return StripDay(date: day,
                            jobs: onDay.filter { $0.status != .requested }.count,
                            requests: onDay.filter { $0.status == .requested }.count,
                            openMinutes: open,
                            isOff: pro?.availability.ranges(on: day).isEmpty ?? true)
        }
    }

    private var weekStrip: some View {
        let days = stripDays
        let jobs = days.reduce(0) { $0 + $1.jobs }
        let hours = ProOpenHours.hours(days.reduce(0) { $0 + $1.openMinutes })
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Next 7 days").labelStyle().accessibilityAddTraits(.isHeader)
                Spacer(minLength: Space.s)
                Button {
                    openCalendar(on: today)
                } label: {
                    HStack(spacing: 6) {
                        Text("Calendar")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Palette.inkFaint)
                    }
                    .font(HDFont.subMedium).foregroundStyle(Palette.ink)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Calendar")
                .accessibilityHint("Opens Calendar")
            }
            if isBusy {
                Text(busyStripLine(jobs: jobs, hours: hours))
                    .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(hours > 0 ? "You've \(ProFlow.count(hours, "hour", "hours")) open." : "Nothing open in the next seven days.")
                    .font(HDFont.titleSmall).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(openHoursLine(hours: hours))
                    .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.xs)
            }
            stripCells(days)
                .padding(.vertical, Space.s)
                .overlay(alignment: .top) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
                .padding(.top, Space.m)
        }
    }

    /// "10 jobs booked, 19 hours still open."
    private func busyStripLine(jobs: Int, hours: Int) -> String {
        let booked = "\(ProFlow.count(jobs, "job", "jobs")) booked"
        return hours > 0 ? "\(booked), \(ProFlow.count(hours, "hour", "hours")) still open." : "\(booked), nothing else open."
    }

    private func openHoursLine(hours: Int) -> String {
        if hours == 0 { return "Add hours or unblock a day in Calendar, and clients can book you." }
        if isLive { return "You're live, so clients can book any of them." }
        if isPaused { return "You're paused, so clients can't book them yet." }
        return "Clients can book them once you're live."
    }

    /// Seven cells; at the accessibility sizes, seven hairline rows.
    @ViewBuilder
    private func stripCells(_ days: [StripDay]) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 0) {
                ForEach(days) { d in
                    HairlineRow(title: "\(d.date.weekday.long) \(d.date.dayNumber)\(d.isToday ? ", today" : "")",
                                subtitle: bookedFacts(d), value: d.isOff ? "Off" : "\(d.hoursLabel) open",
                                showsHairline: d.id != days.last?.id) {
                        openCalendar(on: d.date)
                    }
                }
            }
        } else {
            HStack(spacing: 0) {
                ForEach(days) { d in stripCell(d) }
            }
        }
    }

    private func stripCell(_ d: StripDay) -> some View {
        let onInk = d.isToday
        return Button {
            openCalendar(on: d.date)
        } label: {
            VStack(spacing: 0) {
                Text(d.date.weekday.short).eyebrowStyle(color: onInk ? Palette.onInkSoft : Palette.inkSoft)
                Text(d.date.dayNumber)
                    .font(HDFont.sans(20, relativeTo: .title3).monospacedDigit())
                    .foregroundStyle(onInk ? Palette.onInk : (d.isOff ? Palette.inkSoft : Palette.ink))
                    .padding(.top, 2)
                marks(d, onInk: onInk)
                    .frame(height: 8)
                    .padding(.top, Space.xs)
                Text(d.hoursLabel).font(HDFont.caption).monospacedDigit()
                    .foregroundStyle(onInk ? Palette.onInkSoft : Palette.inkSoft)
                    .padding(.top, Space.xs)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.m)
            .background {
                // Today is the ink cell: the ink ground with its edge, so it keeps one on dark paper.
                if onInk {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .fill(Palette.inkGround)
                        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.inkEdge, lineWidth: 0.5))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stripLabel(d))
        .accessibilityHint("Opens Calendar on this day")
        .accessibilityAddTraits(.isButton)
    }

    /// One ink dot per job, a ring per open request.
    private func marks(_ d: StripDay, onInk: Bool) -> some View {
        let color = onInk ? Palette.onInk : Palette.ink
        return HStack(spacing: 3) {
            ForEach(0..<min(d.jobs, 4), id: \.self) { _ in
                Circle().fill(color).frame(width: 5, height: 5)
            }
            ForEach(0..<min(d.requests, 2), id: \.self) { _ in
                Circle().strokeBorder(color, lineWidth: 1).frame(width: 5, height: 5)
            }
        }
    }

    /// "4 jobs, 1 request", or nil when there's nothing.
    private func bookedFacts(_ d: StripDay) -> String? {
        var facts: [String] = []
        if d.jobs > 0 { facts.append(ProFlow.count(d.jobs, "job", "jobs")) }
        if d.requests > 0 { facts.append(ProFlow.count(d.requests, "request", "requests")) }
        return facts.isEmpty ? nil : facts.joined(separator: ", ")
    }

    /// "Friday 16, today, 4 jobs, 1 hour open"
    private func stripLabel(_ d: StripDay) -> String {
        var parts = ["\(d.date.weekday.long) \(d.date.dayNumber)"]
        if d.isToday { parts.append("today") }
        if let facts = bookedFacts(d) { parts.append(facts) }
        parts.append(d.isOff ? "off" : "\(ProFlow.count(ProOpenHours.hours(d.openMinutes), "hour", "hours")) open")
        return parts.joined(separator: ", ")
    }

    private func openCalendar(on day: Date) {
        Haptics.selection()
        app.calendarDay = day.startOfDay
        app.selectedProTab = .calendar
    }

    // MARK: Get booked

    private var showsShare: Bool { isLive && !hasShared }
    private var showsPhotos: Bool { (pro?.work.count ?? 0) < Self.workTarget }
    private var morning: ProOpenHours.MorningSuggestion? { pro.flatMap { ProOpenHours.morningSuggestion($0.availability.hours) } }
    /// Only while it's off. The switch once her ID's checked and 70% or more of her bookings are
    /// kept; before the check, a line saying so. Checked but under 70%: nothing to offer, so no row.
    private var showsInstant: Bool {
        guard let pro, !pro.instantBook else { return false }
        return !pro.isVerified || pro.reliabilityScore >= 0.7
    }

    /// Up to four things that genuinely help, each gone once it's done. No claims about demand, no counters.
    @ViewBuilder
    private var getBooked: some View {
        if let pro, !isPaused, showsShare || showsPhotos || morning != nil || showsInstant {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Get booked")
                if showsShare { shareRow(pro) }
                if showsPhotos { photosRow(pro) }
                if let morning { hoursRow(morning) }
                if showsInstant { instantRow(pro) }
            }
        }
    }

    private static func sharedKey(_ id: String) -> String { "today.sharedProfile.\(id)" }

    private func shareRow(_ pro: Pro) -> some View {
        GetBookedRow(symbol: "square.and.arrow.up", title: "Share your profile",
                     detail: "Send it to your regulars, so they book you here and not in your DMs.") {
            ShareLink(item: app.shareText(for: pro)) { rowAction("Share") }
                // Remembered now, retired the next time Today appears: taking the row away under
                // the share sheet would take the sheet with it.
                .simultaneousGesture(TapGesture().onEnded {
                    UserDefaults.standard.set(true, forKey: Self.sharedKey(pro.id))
                })
                .accessibilityLabel("Share your profile")
        } extra: {
            EmptyView()
        }
    }

    private func photosRow(_ pro: Pro) -> some View {
        let count = pro.work.count
        return Button {
            Haptics.light()
            path.wrappedValue.append(Route.proWork)
        } label: {
            GetBookedRow(symbol: "photo", title: "Add more work photos",
                         detail: "\(count) of \(Self.workTarget). Close, in daylight, your own work.") {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Palette.inkFaint)
                    .padding(.top, 4)
            } extra: {
                HStack(spacing: Space.xs) {
                    ForEach(pro.work.prefix(Self.workTarget)) { item in
                        WorkTile(item: item, cornerRadius: Radius.photo).frame(width: 30, height: 38)
                    }
                    ForEach(0..<max(0, Self.workTarget - count), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: Radius.photo, style: .continuous)
                            .strokeBorder(Palette.line, lineWidth: 1)
                            .frame(width: 30, height: 38)
                            .overlay(Image(systemName: "plus").font(.system(size: 11, weight: .light)).foregroundStyle(Palette.inkFaint))
                    }
                }
                .padding(.top, Space.s)
                .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Work")
    }

    /// "Open Saturday mornings": "You start at 12 on Saturdays. Opening at 9 adds 3 hours a week."
    private func hoursRow(_ m: ProOpenHours.MorningSuggestion) -> some View {
        let added = m.addedMinutes % 60 == 0 ? ProFlow.count(m.addedMinutes / 60, "hour", "hours") : m.addedMinutes.shortDuration
        return GetBookedRow(symbol: "clock", title: "Open \(m.day.long) mornings",
                            detail: "You start at \(Self.hourWord(m.startMinutes)) on \(m.day.long)s. Opening at 9 adds \(added) a week.") {
            Button {
                Haptics.light()
                path.wrappedValue.append(Destination.hours)
            } label: {
                rowAction("Add")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add \(m.day.long) mornings")
            .accessibilityHint("Opens your hours")
        } extra: {
            EmptyView()
        }
    }

    /// "12", "1", "12:30": the clock without am or pm, which the sentence makes plain.
    private static func hourWord(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        let h12 = h % 12 == 0 ? 12 : h % 12
        return m == 0 ? "\(h12)" : String(format: "%d:%02d", h12, m)
    }

    @ViewBuilder
    private func instantRow(_ pro: Pro) -> some View {
        if pro.isVerified {
            HStack(alignment: .top, spacing: Space.m) {
                GetBookedGlyph(symbol: "bolt").padding(.top, Space.s)
                HDSwitch(title: "Instant book",
                         subtitle: "Your ID's checked, so you can. Clients book your open hours straight in.",
                         isOn: Binding(get: { pro.instantBook }, set: { on in Task { await setInstantBook(on) } }))
                    .disabled(app.isOffline || savingInstant)
            }
            .padding(.vertical, Space.m)
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
        } else {
            GetBookedRow(symbol: "bolt", title: "Instant book", detail: "After your ID check") {
                EmptyView()
            } extra: {
                EmptyView()
            }
        }
    }

    private func setInstantBook(_ on: Bool) async {
        guard var p = app.proSelf, p.instantBook != on else { return }
        savingInstant = true
        defer { savingInstant = false }
        p.instantBook = on
        // Saved, the row goes (it's only offered while off). Not saved, it's back as it was.
        if await app.saveProSelf(p) {
            Haptics.success()
            app.show("Instant book's on. Clients can book your open hours straight in.")
        }
    }

    private func rowAction(_ title: String) -> some View {
        Text(title).font(HDFont.subMedium).foregroundStyle(Palette.ink)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            // The 44pt target, with the word on the title's line.
            .padding(.top, -11)
    }

    // MARK: Your record

    @ViewBuilder
    private var record: some View {
        if let pro {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Your record")
                recordFacts(pro).padding(.top, Space.m)
                if let review = pro.reviews.max(by: { $0.date < $1.date }) {
                    Text("\u{201C}\(review.text)\u{201D}")
                        .font(HDFont.quote).foregroundStyle(Palette.ink)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.xl)
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Text(Self.attribution(review))
                            .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: Space.s)
                        Button {
                            Haptics.light()
                            showAllReviews = true
                        } label: {
                            HStack(spacing: 6) {
                                Text("All \(max(pro.reviewCount, pro.reviews.count))")
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Palette.inkFaint)
                            }
                            .font(HDFont.subMedium).foregroundStyle(Palette.ink)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("All \(max(pro.reviewCount, pro.reviews.count)) reviews")
                    }
                }
            }
        }
    }

    /// RATING and RELIABILITY side by side, like the old money row; stacked at the accessibility sizes.
    private func recordFacts(_ pro: Pro) -> some View {
        let rated = pro.reviewCount > 0
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.l))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 0))
        return layout {
            recordFact("Rating", value: rated ? pro.rating.ratingLabel : "New", star: rated,
                       note: rated ? ProFlow.count(pro.reviewCount, "review", "reviews") : nil)
            if !typeSize.isAccessibilitySize {
                Rectangle().fill(Palette.lineStrong).frame(width: 0.5).padding(.horizontal, Space.l)
            }
            recordFact("Reliability", value: "\(Int((pro.reliabilityScore * 100).rounded()))% kept", note: "Only you see this.")
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func recordFact(_ label: String, value: String, star: Bool = false, note: String?) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(label).labelStyle()
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if star {
                    Image(systemName: "star").font(.system(size: 15, weight: .light)).foregroundStyle(Palette.ink)
                        .accessibilityHidden(true)
                }
                Text(value).font(HDFont.priceLarge).foregroundStyle(Palette.ink)
            }
            if let note { Text(note).font(HDFont.caption).foregroundStyle(Palette.inkSoft) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// "Ruby · BIAB overlay · October" (with the year once it's not this one). A review has her first name only.
    private static func attribution(_ review: Review) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_AU")
        let thisYear = Calendar.current.isDate(review.date, equalTo: Date(), toGranularity: .year)
        f.dateFormat = thisYear ? "MMMM" : "MMMM yyyy"
        var parts = [review.clientFirstName]
        if !review.serviceName.isEmpty { parts.append(review.serviceName) }
        parts.append(f.string(from: review.date))
        return parts.joined(separator: " · ")
    }

    // MARK: Money

    /// "$642.40 this week · $237.60 on its way", "Lands Mon 19 Oct." A $0 figure is left out, and with
    /// nothing either way the row goes. The full stop is lacquer: the one money moment on Today.
    @ViewBuilder
    private var moneyRow: some View {
        let week = earnedWeek
        let pending = app.pendingEarningsCents
        if week > 0 || pending > 0 {
            Button {
                Haptics.light()
                app.selectedProTab = .earnings
            } label: {
                HStack(alignment: .center, spacing: Space.m) {
                    VStack(alignment: .leading, spacing: 2) {
                        moneyLine(week: week, pending: pending)
                            .fixedSize(horizontal: false, vertical: true)
                        if pending > 0, let lands = app.nextPayoutDate {
                            (Text("Lands \(lands.shortDay)").foregroundColor(Palette.inkSoft)
                                + Text(".").fontWeight(.bold).foregroundColor(Palette.lacquer))
                                .font(HDFont.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Palette.inkFaint)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, Space.l)
                .overlay(alignment: .top) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens Earnings")
        }
    }

    private func moneyLine(week: Int, pending: Int) -> Text {
        var parts: [Text] = []
        if week > 0 {
            parts.append(Text(Money.format(week)).foregroundColor(Palette.ink) + Text(" this week").foregroundColor(Palette.inkSoft))
        }
        if pending > 0 {
            parts.append(Text(Money.format(pending)).foregroundColor(Palette.ink) + Text(" on its way").foregroundColor(Palette.inkSoft))
        }
        let line = parts.dropFirst().reduce(parts.first ?? Text("")) { $0 + Text(" · ").foregroundColor(Palette.inkSoft) + $1 }
        return line.font(HDFont.price)
    }
}

/// One "Get booked" row: an outline glyph, what to do, one line of why, anything under it (her
/// photos), and the action on the right. Hairline under.
private struct GetBookedRow<Trailing: View, Extra: View>: View {
    var symbol: String
    var title: String
    var detail: String
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var extra: Extra

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            GetBookedGlyph(symbol: symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(HDFont.body).foregroundStyle(Palette.ink)
                Text(detail).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                extra
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.vertical, Space.l)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
    }
}

/// The outline glyph at the start of a "Get booked" row.
private struct GetBookedGlyph: View {
    var symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 19, weight: .light))
            .foregroundStyle(Palette.ink)
            .frame(width: 24)
            .accessibilityHidden(true)
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
