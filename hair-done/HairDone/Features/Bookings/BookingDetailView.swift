import SwiftUI
import MapKit

/// One booking, top to bottom: who, where it's up to, when, where, what, and what you can do about it.
struct BookingDetailView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    var bookingID: String

    @State private var showReschedule = false
    @State private var showCancel = false
    @State private var showReview = false
    @State private var cancelling = false

    private var booking: Booking? { app.bookings.first { $0.id == bookingID } }

    var body: some View {
        Group {
            if let booking {
                content(booking)
            } else {
                EmptyState(symbol: "questionmark.circle", title: "We couldn't find that one.", actionTitle: "Back") { dismiss() }
                    .paperBackground()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Content

    private func content(_ booking: Booking) -> some View {
        let pro = app.pro(booking.proID)
        let proName = pro?.firstName ?? "her"
        return ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                header(booking, pro: pro, proName: proName)
                BookingTimeline(booking: booking, pro: pro)
                whenSection(booking)
                whereSection(booking)
                whatSection(booking)
                if !booking.notes.isEmpty || !booking.inspoSeeds.isEmpty { notesSection(booking) }
                if let review = booking.review { reviewSection(review, proName: proName) }
                actions(booking, pro: pro, proName: proName)
            }
            .screenGutter()
            .padding(.top, Space.s)
            .padding(.bottom, Space.section)
        }
        .paperBackground()
        .navigationTitle(booking.cardTitle(proName: proName))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { simulateMenu(booking) }
        }
        .sheet(isPresented: $showReschedule) {
            RescheduleSheet(booking: booking)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showReview) {
            ReviewSheet(booking: booking)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCancel) {
            CancelBookingSheet(booking: booking, proName: proName, isWorking: cancelling) {
                cancelling = true
                Task {
                    let line = booking.cancelDoneLine(proName: proName)
                    if await app.update(booking, to: .cancelledByClient) != nil {
                        showCancel = false
                        app.show(line)
                    }
                    cancelling = false
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: Header

    private func header(_ booking: Booking, pro: Pro?, proName: String) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            if let pro {
                NavigationLink(value: Route.pro(pro)) {
                    HStack(spacing: Space.m) {
                        Avatar(name: pro.firstName, seed: pro.seed, size: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(pro.displayName).font(HDFont.heading).foregroundStyle(Palette.ink)
                                if pro.isVerified { VerifiedBadge(compact: true) }
                            }
                            Text(pro.specialtyLine).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                            RatingLine(rating: pro.rating, count: pro.reviewCount)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                    }
                    .card()
                }
                .buttonStyle(PressLift(scale: 0.985))
                .accessibilityElement(children: .combine)
                .accessibilityHint("Opens her profile")
            }

            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                StatusBadge(status: booking.status)
                Spacer(minLength: 0)
                Text(booking.reference)
                    .font(HDFont.label.monospacedDigit())
                    .foregroundStyle(Palette.inkSoft)
                    .accessibilityLabel("Reference \(booking.reference)")
            }
            HStack(spacing: Space.s) {
                if booking.isToday && booking.status.isUpcoming { LiveDot(color: booking.status.color) }
                Text(booking.status.clientLine(pro: proName))
                    .font(HDFont.body)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if booking.status == .declined, let reason = booking.declineReason, !reason.isEmpty {
                Text(reason).italic().font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            }
        }
    }

    // MARK: When

    private func whenSection(_ booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("When").labelStyle()
            Text(booking.start.friendlyDayTime).font(HDFont.heading).foregroundStyle(Palette.ink)
            Text("Till about \(booking.end.clock) · \(booking.minutes.minutesLabel)").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Where

    private func whereSection(_ booking: Booking) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: booking.address.latitude, longitude: booking.address.longitude)
        return VStack(alignment: .leading, spacing: Space.s) {
            Text("Where").labelStyle()
            Text(booking.address.label).font(HDFont.bodyStrong).foregroundStyle(Palette.ink)
            Text(booking.address.full).font(HDFont.body).foregroundStyle(Palette.ink)
            if !booking.address.instructions.isEmpty {
                Text(booking.address.instructions).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            }
            Button {
                Haptics.light()
                let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                item.name = booking.address.label
                item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
            } label: {
                Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 900, longitudinalMeters: 900))) {
                    Marker(booking.address.label, coordinate: coordinate).tint(Palette.lacquer)
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .allowsHitTesting(false)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
                .overlay(alignment: .bottomTrailing) {
                    Text("Open in Maps")
                        .font(HDFont.label)
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Palette.paper.opacity(0.92), in: Capsule())
                        .padding(10)
                }
            }
            .buttonStyle(PressLift(scale: 0.985))
            .padding(.top, Space.xs)
            .accessibilityLabel("Map of \(booking.address.short)")
            .accessibilityHint("Opens in Apple Maps")
        }
    }

    // MARK: What

    private func whatSection(_ booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("What").labelStyle()
            VStack(spacing: Space.m) {
                ForEach(booking.services) { s in
                    PriceRow(label: s.name, cents: s.priceCents, note: s.durationLabel)
                }
                PriceRow(label: "Travel fee", cents: booking.price.travelFeeCents)
                PriceRow(label: "Hair Done booking fee", cents: booking.price.bookingFeeCents)
                if booking.price.tipCents > 0 { PriceRow(label: "Tip", cents: booking.price.tipCents, note: "All of it went to her") }
                Hairline()
                PriceRow(label: "Total", cents: booking.price.clientTotalCents, emphasis: true)
            }
            .card()
        }
    }

    // MARK: Notes and photos

    private func notesSection(_ booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            if !booking.notes.isEmpty {
                Text("Notes").labelStyle()
                Text(booking.notes).font(HDFont.body).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
            }
            if !booking.inspoSeeds.isEmpty {
                Text("Your photos").labelStyle().padding(.top, booking.notes.isEmpty ? 0 : Space.s)
                HStack(spacing: Space.s) {
                    ForEach(Array(booking.inspoSeeds.enumerated()), id: \.offset) { i, seed in
                        WorkTile(item: WorkItem(id: "inspo_\(booking.id)_\(i)", category: booking.primaryCategory, caption: "Inspo photo \(i + 1)", seed: seed))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }

    // MARK: Your review

    private func reviewSection(_ review: Review, proName: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("What you said").labelStyle()
            VStack(alignment: .leading, spacing: Space.s) {
                HStack {
                    StarsRow(rating: review.rating, size: 14)
                    Spacer()
                    Text(review.date.shortDay).font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                }
                if !review.text.isEmpty {
                    Text(review.text).font(HDFont.body).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                }
                if let reply = review.proReply, !reply.isEmpty {
                    Hairline()
                    Text("\(proName) replied").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    Text(reply).font(HDFont.sub).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                }
            }
            .card()
        }
    }

    // MARK: Actions

    @ViewBuilder
    private func actions(_ booking: Booking, pro: Pro?, proName: String) -> some View {
        VStack(spacing: Space.m) {
            switch booking.status {
            case .requested, .confirmed:
                messageButton(booking, proName: proName)
                SecondaryButton(title: "Reschedule", symbol: "calendar") { showReschedule = true }
                TertiaryButton(title: "Cancel booking", tint: Palette.lacquer) { showCancel = true }

            case .onHerWay, .arrived, .inProgress:
                messageButton(booking, proName: proName)
                ShareLink(item: booking.shareText(proName: proName)) {
                    shareLabel("Share with a friend", symbol: "square.and.arrow.up")
                }
                .buttonStyle(PressLift())
                .simultaneousGesture(TapGesture().onEnded { Haptics.light() })

            case .done, .paid:
                if booking.review == nil {
                    PrimaryButton(title: "Rate \(proName)", symbol: "star") { showReview = true }
                }
                if let pro {
                    NavigationLink(value: Route.pro(pro)) { secondaryLabel("Book again", symbol: "arrow.counterclockwise") }
                        .buttonStyle(PressLift())
                        .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
                }
                ShareLink(item: booking.receiptText(proName: proName), subject: Text("Hair Done receipt \(booking.reference)")) {
                    Text("Get receipt").font(HDFont.subStrong).foregroundStyle(Palette.inkSoft).frame(minHeight: 44)
                }
                .simultaneousGesture(TapGesture().onEnded { Haptics.light() })

            case .cancelledByClient, .cancelledByPro, .declined, .noShow:
                if let pro {
                    NavigationLink(value: Route.pro(pro)) { secondaryLabel("Book again", symbol: "arrow.counterclockwise") }
                        .buttonStyle(PressLift())
                        .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
                }
            }
        }
        .padding(.top, Space.s)
    }

    @ViewBuilder
    private func messageButton(_ booking: Booking, proName: String) -> some View {
        if let thread = app.thread(for: booking) {
            NavigationLink(value: Route.thread(thread.id)) {
                Text("Message \(proName)")
                    .font(HDFont.bodyStrong)
                    .foregroundStyle(Palette.onLacquer)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Palette.lacquer, in: Capsule())
            }
            .buttonStyle(PressLift())
            .simultaneousGesture(TapGesture().onEnded { Haptics.medium() })
        }
    }

    private func secondaryLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(HDFont.bodyStrong)
        .foregroundStyle(Palette.ink)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Palette.card, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
    }

    private func shareLabel(_ title: String, symbol: String) -> some View {
        secondaryLabel(title, symbol: symbol)
    }

    // MARK: Simulate (debug only)

    /// Walks a booking along the happy path so the timeline can be shown off. Not in release builds.
    @ViewBuilder
    private func simulateMenu(_ booking: Booking) -> some View {
        #if DEBUG
        Menu {
            if let next = nextStatus(after: booking.status) {
                Button {
                    Task { await app.update(booking, to: next) }
                } label: {
                    Label("Move to \(next.timelineTitle)", systemImage: "arrow.right")
                }
            } else {
                Text("Nothing further to simulate")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(Palette.inkSoft)
        }
        .accessibilityLabel("Simulate")
        #else
        EmptyView()
        #endif
    }

    private func nextStatus(after status: BookingStatus) -> BookingStatus? {
        switch status {
        case .requested: return .confirmed
        case .confirmed: return .onHerWay
        case .onHerWay: return .arrived
        case .arrived, .inProgress: return .done
        case .done: return .paid
        default: return nil
        }
    }
}

// MARK: - Timeline

/// requested → confirmed → on her way → here → done → paid, as a vertical stepper.
/// A cancelled or declined booking ends on a grey step with the reason.
struct BookingTimeline: View {
    var booking: Booking
    var pro: Pro?

    private var proName: String { pro?.firstName ?? "her" }
    private var currentIndex: Int { booking.status.timelineIndex ?? -1 }
    private var isOffPath: Bool { booking.status.isCancelled }

    private var steps: [BookingStatus] {
        if isOffPath {
            // Only steps that can come before a cancel or decline. Nothing after "here".
            let possible = BookingStatus.timeline.prefix(through: BookingStatus.timeline.firstIndex(of: .arrived) ?? 3)
            let happened = possible.filter { booking.eventTime(for: $0) != nil }
            return happened + [booking.status]
        }
        return BookingStatus.timeline
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                let reached = isOffPath ? true : i <= currentIndex
                let isCurrent = step == booking.status || (booking.status == .inProgress && step == .arrived)
                let isLast = i == steps.count - 1
                HStack(alignment: .top, spacing: Space.m) {
                    VStack(spacing: 0) {
                        dot(reached: reached, current: isCurrent, grey: step.isCancelled)
                        if !isLast {
                            Rectangle()
                                .fill(reached && !(isOffPath && step == booking.status) ? Palette.lacquer.opacity(0.5) : Palette.line)
                                .frame(width: 2)
                                .frame(minHeight: 22)
                        }
                    }
                    .frame(width: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(step.timelineTitle)
                                .font(isCurrent ? HDFont.bodyStrong : HDFont.body)
                                .foregroundStyle(reached ? Palette.ink : Palette.inkFaint)
                            Spacer(minLength: 0)
                            if let at = booking.eventTime(for: step) {
                                Text(at.friendlyDay == "Today" ? at.clock : "\(at.friendlyDay), \(at.clock)")
                                    .font(HDFont.caption.monospacedDigit())
                                    .foregroundStyle(Palette.inkSoft)
                            }
                        }
                        if isCurrent, let sub = subline(for: step) {
                            Text(sub).font(HDFont.sub).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.bottom, isLast ? 0 : Space.m)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(step.timelineTitle)\(reached ? "" : ", not yet")\(isCurrent ? ", current" : "")")
            }
        }
        .card()
    }

    private func dot(reached: Bool, current: Bool, grey: Bool) -> some View {
        ZStack {
            if current && !grey {
                Circle().fill(Palette.lacquerSoft).frame(width: 16, height: 16)
            }
            Circle()
                .fill(reached ? (grey ? Palette.inkFaint : Palette.lacquer) : Palette.card)
                .frame(width: 10, height: 10)
                .overlay(Circle().strokeBorder(reached ? Color.clear : Palette.line, lineWidth: 1.5))
        }
        .frame(width: 16, height: 22)
    }

    /// Copy deck `detail.timeline.*.sub`, only under the step you're on.
    private func subline(for step: BookingStatus) -> String? {
        switch step {
        case .requested:
            let mins = pro?.responseMinutes ?? 60
            return "She usually replies within \(mins.minutesLabel)."
        case .confirmed:
            let day = booking.start.friendlyDay
            let spoken = (day == "Today" || day == "Tomorrow") ? day.lowercased() : day
            return "See you \(spoken) at \(booking.start.clock)."
        case .onHerWay:
            if let pro { return "About \(booking.travelMinutes(from: pro)) minutes out." }
            return "She's on the road."
        case .arrived:
            return booking.status == .inProgress ? "Happening now." : "Put the kettle on."
        case .done:
            return "Charging \(Money.format(booking.price.clientTotalCents)) now."
        case .paid:
            return "\(Money.format(booking.price.clientTotalCents)) to \(proName). Receipt's in your inbox."
        case .declined:
            return booking.declineReason ?? "\(proName) couldn't do it this time."
        case .cancelledByClient:
            return nil
        case .cancelledByPro:
            return "Refunded in full."
        case .noShow:
            return "Charged in full."
        case .inProgress:
            return "Happening now."
        }
    }
}

// MARK: - Cancel sheet

/// Says exactly what cancelling costs before you do it.
struct CancelBookingSheet: View {
    @Environment(\.dismiss) private var dismiss
    var booking: Booking
    var proName: String
    var isWorking: Bool
    var onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            SheetHeader(title: "Cancel this booking?", onClose: { dismiss() })
            VStack(alignment: .leading, spacing: Space.m) {
                Text(booking.cancelBody(proName: proName))
                    .font(HDFont.body)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if booking.cancellationChargeCents > 0 {
                    PriceRow(label: "You'll pay", cents: booking.cancellationChargeCents, emphasis: true)
                        .card()
                }
            }
            .screenGutter()
            Spacer(minLength: 0)
            VStack(spacing: Space.s) {
                PrimaryButton(title: booking.cancelButtonTitle, isLoading: isWorking, action: onConfirm)
                TertiaryButton(title: "Keep it") { dismiss() }
            }
            .screenGutter()
            .padding(.bottom, Space.l)
        }
        .paperBackground()
    }
}

#Preview("Tonight, confirmed") {
    NavigationStack { BookingDetailView(bookingID: "bk_1") }.environment(previewApp())
}

#Preview("Paid, rated") {
    NavigationStack { BookingDetailView(bookingID: "bk_4") }.environment(previewApp())
}

#Preview("Cancelled") {
    NavigationStack { BookingDetailView(bookingID: "bk_7") }.environment(previewApp())
}
