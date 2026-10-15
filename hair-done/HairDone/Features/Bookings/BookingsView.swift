import SwiftUI

/// The Bookings tab: what's coming up, and what's been. Paper, hairline rows, her photos.
/// The first booking to come is the same ink Next up block Home shows.
struct BookingsView: View {
    @Environment(AppState.self) private var app
    /// Kept on AppState so switching sides and back lands her where she was.
    private var path: Binding<NavigationPath> { app.path(for: ClientTab.bookings) }
    @State private var segment: Segment = .upcoming
    @State private var reviewing: Booking? = nil
    @State private var paying: Booking? = nil

    enum Segment: String, CaseIterable { case upcoming = "Upcoming", past = "Past" }

    var body: some View {
        NavigationStack(path: path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .screenGutter()
                        .padding(.top, Space.s)
                        .padding(.bottom, Space.l)

                    if app.isOffline { OfflineBar().padding(.bottom, Space.m) }

                    switch segment {
                    case .upcoming: upcoming
                    case .past: past
                    }
                }
                .padding(.bottom, Space.section)
            }
            .paperBackground()
            .refreshable { await app.loadBookings() }
            .task {
                if !app.hasLoadedBookings && !app.isLoadingBookings { await app.loadBookings() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .hdDestinations()
            .sheet(item: $reviewing) { booking in
                ReviewSheet(booking: booking)
            }
            .sheet(item: $paying) { booking in
                PaySheet(booking: booking)
            }
            .animation(Motion.gentle, value: app.isOffline)
        }
        .receivesPendingRoutes(path) { $0.isBooking }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(eyebrow).labelStyle()
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    title
                    Spacer(minLength: Space.m)
                    tabs
                }
                VStack(alignment: .leading, spacing: Space.xs) {
                    title
                    tabs
                }
            }
        }
    }

    private var title: some View {
        Text("Bookings.")
            .font(HDFont.display)
            .foregroundStyle(Palette.ink)
            .accessibilityAddTraits(.isHeader)
    }

    private var tabs: some View {
        TextTabs(selection: $segment, options: Segment.allCases) { $0.rawValue }
    }

    private var eyebrow: String {
        let n = app.upcomingBookings.count
        switch n {
        case 0: return "Nothing on"
        case 1: return "1 coming up"
        default: return "\(n) coming up"
        }
    }

    /// Rows loading until the first load comes back, instead of flashing "Nothing on".
    private var isLoading: Bool { app.showsBookingsSkeleton }

    // MARK: Upcoming

    @ViewBuilder
    private var upcoming: some View {
        let list = app.upcomingBookings
        if isLoading {
            ListSkeleton(rows: 3)
        } else if list.isEmpty {
            if app.bookingsLoadFailed {
                ErrorState { Task { await app.loadBookings() } }
            } else {
                if let first = app.awaitingReview.first { nudge(first).screenGutter() }
                EmptyState(title: "Nothing on. Want to change that?", actionTitle: "See who's free") {
                    app.selectedTab = .home
                }
                freeRail
            }
        } else {
            if app.bookingsLoadFailed { refreshFailed }
            VStack(alignment: .leading, spacing: 0) {
                if let first = list.first {
                    HomeNextUpCard(booking: first, pro: app.pro(first.proID)) {
                        path.wrappedValue.append(Route.booking(first.id))
                    }
                    .padding(.bottom, Space.m)
                }
                ForEach(list.dropFirst()) { booking in
                    BookingRow(booking: booking, pro: app.pro(booking.proID))
                }
                if let first = app.awaitingReview.first { nudge(first).padding(.top, Space.l) }
            }
            .screenGutter()
        }
    }

    // MARK: Past

    @ViewBuilder
    private var past: some View {
        let list = app.pastBookings
        if isLoading {
            ListSkeleton(rows: 3)
        } else if list.isEmpty {
            if app.bookingsLoadFailed {
                ErrorState { Task { await app.loadBookings() } }
            } else {
                EmptyState(title: "Nothing yet. Your first one goes here.")
            }
        } else {
            if app.bookingsLoadFailed { refreshFailed }
            VStack(alignment: .leading, spacing: 0) {
                if let first = app.awaitingReview.first { nudge(first).padding(.bottom, Space.s) }
                ForEach(list) { booking in
                    let pro = app.pro(booking.proID)
                    BookingRow(booking: booking, pro: pro, isPast: true, onBookAgain: pro == nil ? nil : { if let p = pro { path.wrappedValue.append(Route.pro(p)) } })
                }
            }
            .screenGutter()
        }
    }

    /// The list is from before; the refresh didn't come back.
    private var refreshFailed: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            FieldMessage(text: "Couldn't refresh. This is what we had.")
            Spacer(minLength: 0)
            TertiaryButton(title: "Try again", tint: Palette.ink) { Task { await app.loadBookings() } }
        }
        .screenGutter()
        .padding(.bottom, Space.s)
    }

    // MARK: Pay or rate

    /// A done booking waiting on payment ("Pay Kiara") or a paid one waiting on stars ("How'd Kiara go?").
    @ViewBuilder
    private func nudge(_ booking: Booking) -> some View {
        let name = app.pro(booking.proID)?.firstName ?? "her"
        if booking.status == .done {
            Button {
                Haptics.light()
                paying = booking
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pay \(name)").font(HDFont.name).foregroundStyle(Palette.ink)
                    Text("\(booking.servicesLine) · \(Money.format(booking.price.clientTotalCents)). Or we'll charge your card at \(booking.autoChargeAt.clock).")
                        .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Space.m)
                .overlay(alignment: .bottom) { Hairline(strong: true) }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressLift(scale: 0.99))
            .disabled(app.isOffline)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens Pay")
        } else {
            Button {
                Haptics.light()
                reviewing = booking
            } label: {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("How'd \(name) go?").font(HDFont.name).foregroundStyle(Palette.ink)
                    HStack(spacing: 6) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(systemName: "star").font(.system(size: 22, weight: .light)).foregroundStyle(Palette.ink)
                        }
                    }
                    Text("\(booking.servicesLine) · \(booking.start.friendlyDay). Two taps.")
                        .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Space.m)
                .overlay(alignment: .bottom) { Hairline(strong: true) }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressLift(scale: 0.99))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Rate \(name), \(booking.servicesLine)")
            .accessibilityHint("Opens the rating sheet")
        }
    }

    // MARK: Who's free, under the empty state

    @ViewBuilder
    private var freeRail: some View {
        let free = app.pros.filter { app.whosFree[$0.id] != nil && $0.id != app.proSelf?.id }
        let shown = Array((free.isEmpty ? app.pros.filter { $0.id != app.proSelf?.id } : free).prefix(8))
        if !shown.isEmpty {
            VStack(alignment: .leading, spacing: Space.m) {
                Text(free.isEmpty ? "Near you" : "Free today").labelStyle().screenGutter()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Space.m) {
                        ForEach(shown) { pro in
                            HomePortraitTile(item: pro.homeCover,
                                             width: 150,
                                             title: pro.firstName,
                                             line: freeLine(pro)) {
                                path.wrappedValue.append(Route.pro(pro))
                            }
                        }
                    }
                    .padding(.horizontal, Space.gutter)
                }
            }
        }
    }

    private func freeLine(_ pro: Pro) -> String {
        if let at = app.whosFree[pro.id] { return "Free from \(at.clock)" }
        return pro.specialtyLine
    }
}

// MARK: - Row

/// One booking as a hairline row: her photo 72x90 at 2pt, a status eyebrow, the serif title and
/// one SF line. Past rows dim the photo and offer "Book again" as an ink text link.
struct BookingRow: View {
    var booking: Booking
    var pro: Pro?
    var isPast = false
    var onBookAgain: (() -> Void)? = nil

    private var proName: String { pro?.firstName ?? "her" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: Route.booking(booking.id)) {
                HStack(alignment: .top, spacing: Space.l) {
                    BookingPhoto(item: booking.coverItem(pro: pro))
                        .frame(width: 72, height: 90)
                        .opacity(isPast ? 0.7 : 1)
                    VStack(alignment: .leading, spacing: 4) {
                        BookingStatusEyebrow(status: booking.status, live: booking.isToday && booking.status.isActiveDay)
                        Text(booking.cardTitle(proName: proName))
                            .font(HDFont.name)
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(isPast ? "\(booking.start.shortDay) · \(booking.address.suburb)" : booking.whenWhereLine)
                            .font(HDFont.sub)
                            .foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        if isPast, let review = booking.review {
                            StarsRow(rating: review.rating).padding(.top, 2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressLift(scale: 0.99))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(booking.cardTitle(proName: proName)), \(isPast ? booking.start.shortDay : booking.whenWhereLine), \(booking.status.label)")
            .accessibilityHint("Opens the booking")

            if isPast { pastFoot }
        }
        .padding(.vertical, Space.m)
        .overlay(alignment: .bottom) {
            // The hairline sits under the text column, as on Home's Near you.
            Rectangle().fill(Palette.lineStrong).frame(height: 0.5).padding(.leading, 72 + Space.l)
        }
    }

    /// "Book again" and the price, under the text column.
    private var pastFoot: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            if let onBookAgain {
                TertiaryButton(title: "Book again", tint: Palette.ink, action: onBookAgain)
                    .padding(.leading, -8)
                    .accessibilityHint("Opens her profile")
            }
            Spacer(minLength: 0)
            if let priceLine {
                Text(priceLine)
                    .font(HDFont.priceSmall)
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .padding(.leading, 72 + Space.l)
    }

    /// The total, or "Not charged" when she cancelled or declined. Nothing for the client's own
    /// cancel: whether a late fee applied isn't on the booking.
    private var priceLine: String? {
        switch booking.status {
        case .cancelledByPro, .declined: return "Not charged"
        case .cancelledByClient: return nil
        default: return Money.format(booking.price.clientTotalCents)
        }
    }
}

#Preview("Bookings") {
    BookingsView().environment(previewApp())
}

#Preview("Bookings, empty") {
    let app = previewApp()
    app.bookings = []
    return BookingsView().environment(app)
}
