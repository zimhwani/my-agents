import SwiftUI

/// The Bookings tab: what's coming up, and what's been.
struct BookingsView: View {
    @Environment(AppState.self) private var app
    @State private var path = NavigationPath()
    @State private var segment: Segment = .upcoming
    @State private var reviewing: Booking? = nil

    enum Segment: String, CaseIterable { case upcoming = "Upcoming", past = "Past" }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    Text("Bookings")
                        .font(HDFont.hero)
                        .foregroundStyle(Palette.ink)
                        .padding(.top, Space.s)
                        .accessibilityAddTraits(.isHeader)

                    HStack(spacing: Space.s) {
                        ForEach(Segment.allCases, id: \.self) { s in
                            Chip(title: s.rawValue, isSelected: segment == s) {
                                withAnimation(Motion.spring) { segment = s }
                            }
                        }
                    }
                    .padding(.bottom, Space.s)

                    switch segment {
                    case .upcoming: upcoming
                    case .past: past
                    }
                }
                .screenGutter()
                .padding(.bottom, Space.section)
            }
            .paperBackground()
            .refreshable { await app.loadBookings() }
            .toolbar(.hidden, for: .navigationBar)
            .hdDestinations()
            .sheet(item: $reviewing) { booking in
                ReviewSheet(booking: booking)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: Upcoming

    @ViewBuilder
    private var upcoming: some View {
        let list = app.upcomingBookings
        if list.isEmpty {
            if let first = app.awaitingReview.first, let pro = app.pro(first.proID) {
                rateNudge(first, pro: pro)
            }
            EmptyState(symbol: "calendar", title: "Nothing on. Want to change that?", actionTitle: "See who's free") {
                app.selectedTab = .home
            }
        } else {
            ForEach(list) { booking in
                UpcomingBookingCard(booking: booking, pro: app.pro(booking.proID))
            }
        }
    }

    // MARK: Past

    @ViewBuilder
    private var past: some View {
        let list = app.pastBookings
        if let first = app.awaitingReview.first, let pro = app.pro(first.proID) {
            rateNudge(first, pro: pro)
        }
        if list.isEmpty {
            EmptyState(symbol: "clock", title: "Nothing yet. Your first one goes here.")
        } else {
            ForEach(list) { booking in
                PastBookingCard(booking: booking, pro: app.pro(booking.proID)) {
                    if let pro = app.pro(booking.proID) { path.append(Route.pro(pro)) }
                } onRate: {
                    reviewing = booking
                }
            }
        }
    }

    /// The gentle "How'd she go?" card for a paid booking you haven't rated.
    private func rateNudge(_ booking: Booking, pro: Pro) -> some View {
        Button {
            Haptics.light()
            reviewing = booking
        } label: {
            HStack(spacing: Space.m) {
                Avatar(name: pro.firstName, seed: pro.seed, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("How'd \(pro.firstName) go?").font(HDFont.heading).foregroundStyle(Palette.ink)
                    Text("\(booking.servicesLine) · \(booking.start.friendlyDay). Two taps.").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                }
                Spacer(minLength: 0)
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.honey)
                    }
                }
            }
            .card()
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.honey.opacity(0.6), lineWidth: 1))
        }
        .buttonStyle(PressLift(scale: 0.985))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rate \(pro.firstName), \(booking.servicesLine)")
        .accessibilityHint("Opens the rating sheet")
    }
}

// MARK: - Cards

/// A booking that's still to come. If it's today, it breathes.
struct UpcomingBookingCard: View {
    var booking: Booking
    var pro: Pro?

    private var proName: String { pro?.firstName ?? "her" }

    var body: some View {
        NavigationLink(value: Route.booking(booking.id)) {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(alignment: .top, spacing: Space.m) {
                    Avatar(name: proName, seed: pro?.seed ?? 0, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(booking.cardTitle(proName: proName))
                            .font(HDFont.bodyStrong)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(booking.whenWhereLine)
                            .font(HDFont.sub)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Spacer(minLength: 0)
                    StatusBadge(status: booking.status)
                }
                if booking.isToday {
                    Hairline()
                    HStack(spacing: Space.s) {
                        LiveDot(color: booking.status.color)
                        Text(booking.status.clientLine(pro: proName))
                            .font(HDFont.sub)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Text(booking.start.clock).font(HDFont.subStrong.monospacedDigit()).foregroundStyle(Palette.ink)
                    }
                }
            }
            .card()
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(booking.isToday ? booking.status.color.opacity(0.35) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PressLift(scale: 0.985))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(booking.cardTitle(proName: proName)), \(booking.whenWhereLine), \(booking.status.label)")
        .accessibilityHint("Opens the booking")
    }
}

/// A booking that's been. Muted, with a way back to her.
struct PastBookingCard: View {
    var booking: Booking
    var pro: Pro?
    var onBookAgain: () -> Void
    var onRate: () -> Void

    private var proName: String { pro?.firstName ?? "her" }
    private var canRate: Bool { booking.status.isFinished && booking.review == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            NavigationLink(value: Route.booking(booking.id)) {
                HStack(alignment: .top, spacing: Space.m) {
                    Avatar(name: proName, seed: pro?.seed ?? 0, size: 44).opacity(0.75)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(booking.cardTitle(proName: proName))
                            .font(HDFont.bodyStrong)
                            .foregroundStyle(Palette.ink.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(booking.start.shortDay) · \(booking.address.suburb)")
                            .font(HDFont.sub)
                            .foregroundStyle(Palette.inkSoft)
                        if let review = booking.review {
                            StarsRow(rating: review.rating).padding(.top, 2)
                        }
                    }
                    Spacer(minLength: 0)
                    StatusBadge(status: booking.status)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressLift(scale: 0.985))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(booking.cardTitle(proName: proName)), \(booking.start.shortDay), \(booking.status.label)")
            .accessibilityHint("Opens the booking")

            Hairline()
            HStack(spacing: Space.s) {
                if pro != nil {
                    TertiaryButton(title: "Book again", tint: Palette.lacquer, action: onBookAgain)
                }
                if canRate {
                    TertiaryButton(title: "Rate \(proName)", action: onRate)
                }
                Spacer(minLength: 0)
                Text(Money.format(booking.price.clientTotalCents))
                    .font(HDFont.price)
                    .foregroundStyle(booking.status.isCancelled ? Palette.inkFaint : Palette.inkSoft)
                    .strikethrough(booking.status.isCancelled, color: Palette.inkFaint)
                    .accessibilityLabel(booking.status.isCancelled ? "Not charged" : "Paid \(Money.format(booking.price.clientTotalCents))")
            }
        }
        .card()
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
