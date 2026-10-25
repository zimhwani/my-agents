import SwiftUI
import MapKit

/// One booking, top to bottom. It opens on the same record she was handed when she booked (her
/// pro's photo, the name in serif, when, where and what), then what she can do about it, where
/// it's up to, and the receipt. Refreshes itself on the day.
struct BookingDetailView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    var bookingID: String

    @State private var showReschedule = false
    @State private var showCancel = false
    @State private var showReview = false
    @State private var showPay = false
    @State private var showReceipt = false
    @State private var cancelling = false
    @State private var cancelProblem: String? = nil
    @State private var confirmFlag = false

    private var booking: Booking? { app.bookings.first { $0.id == bookingID } }

    var body: some View {
        Group {
            if let booking {
                content(booking)
            } else if app.bookingsLoadFailed {
                ErrorState { Task { await app.loadBookings() } }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .paperBackground()
                    .hdNavHeader()
            } else {
                EmptyState(title: "We couldn't find that one.", message: "It might have been moved or cancelled.", actionTitle: "Back") { dismiss() }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .paperBackground()
                    .hdNavHeader()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await app.loadBookings(people: false) } }
        }
    }

    // MARK: Content

    private func content(_ booking: Booking) -> some View {
        let pro = app.pro(booking.proID)
        let proName = pro?.firstName ?? "her"
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if app.isOffline { OfflineBar() }
                // The back glyph sits bare on the photo and scrolls away with it, so it never floats
                // over the paper below.
                cover(booking, pro: pro)
                    .hdNavHeader(nil, tone: .onPhoto) { simulateMenu(booking) }
                VStack(alignment: .leading, spacing: Space.section) {
                    header(booking, pro: pro, proName: proName)
                    actions(booking, pro: pro, proName: proName)
                    timeline(booking, pro: pro)
                    receipt(booking)
                    whereSection(booking)
                    if !booking.notes.isEmpty || hasPhotos(booking) { notesSection(booking) }
                    if let review = booking.review { reviewSection(review, proName: proName) }
                    after(booking, pro: pro, proName: proName)
                }
                .screenGutter()
                .padding(.top, Space.l)
                .padding(.bottom, Space.section)
            }
        }
        .paperBackground()
        .refreshable { await app.loadBookings() }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarPaper()
        .animation(Motion.gentle, value: app.isOffline)
        // On the day, between confirmed and done, look for her moves every 30 seconds.
        .task(id: booking.status) {
            guard Self.polls(booking) else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if Task.isCancelled { break }
                await app.loadBookings(people: false)
            }
        }
        .sheet(isPresented: $showReschedule) {
            RescheduleSheet(booking: booking)
        }
        .sheet(isPresented: $showReview) {
            ReviewSheet(booking: booking)
        }
        .sheet(isPresented: $showPay) {
            PaySheet(booking: booking)
        }
        .sheet(isPresented: $showReceipt) {
            ReceiptSheet(booking: booking)
        }
        .sheet(isPresented: $showCancel) {
            cancelSheet(booking, proName: proName)
        }
        .confirmSheet(isPresented: $confirmFlag,
                      title: "Something wrong?",
                      message: "We'll hold off charging your card for up to 48 hours while a person looks. Then message us from Help and say what happened.",
                      confirmTitle: "Hold off the charge",
                      cancelTitle: "Leave it") {
            Task {
                if await app.flag(booking, detail: "") {
                    app.show("Held off. A person will be in touch within two days.")
                }
            }
        }
    }

    private static func polls(_ b: Booking) -> Bool {
        b.isToday && [.confirmed, .onHerWay, .arrived, .inProgress, .done].contains(b.status)
    }

    // MARK: The record

    private func cover(_ booking: Booking, pro: Pro?) -> some View {
        Group {
            if let pro {
                NavigationLink(value: Route.pro(pro)) { coverPhoto(booking, pro: pro) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(pro.displayName)'s work")
                    .accessibilityHint("Opens her profile")
            } else {
                coverPhoto(booking, pro: nil)
            }
        }
    }

    private func coverPhoto(_ booking: Booking, pro: Pro?) -> some View {
        Color.clear
            .aspectRatio(3.0 / 2.0, contentMode: .fit)
            .overlay { BookingPhoto(item: booking.coverItem(pro: pro), cornerRadius: 0) }
            .clipped()
            .opacity(booking.status.isCancelled ? 0.7 : 1)
    }

    private func header(_ booking: Booking, pro: Pro?, proName: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                BookingStatusEyebrow(status: booking.status, live: booking.isToday && booking.status.isActiveDay)
                Spacer(minLength: Space.s)
                Text(booking.reference)
                    .font(HDFont.caption.monospacedDigit())
                    .foregroundStyle(Palette.inkSoft)
                    .accessibilityLabel("Reference \(booking.reference)")
            }
            Text(pro?.displayName ?? "Your booking")
                .font(HDFont.title)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.s)
                .accessibilityAddTraits(.isHeader)
            recordLines(booking)
                .font(HDFont.quote)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.s)
            Text(statusLine(booking, proName: proName))
                .font(HDFont.body)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.l)
            if booking.status == .declined, let reason = booking.declineReason, !reason.isEmpty {
                Text(reason).font(HDFont.italicSub).foregroundStyle(Palette.inkSoft).padding(.top, Space.xs)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// "Thursday 23 October, 6:15 pm / at yours in Fitzroy North / BIAB overlay · $113 held."
    /// The full stop is lacquer, as on You're booked, except when Pay is the lacquer on screen.
    private func recordLines(_ booking: Booking) -> Text {
        let when = "\(booking.start.hdLongDay), \(booking.start.clock)"
        let label = booking.address.label.trimmingCharacters(in: .whitespaces)
        let place: String
        switch label.lowercased() {
        case "", "home", "here": place = "at yours"
        case "work": place = "at work"
        default: place = "at \(label)"
        }
        let whereLine = "\(place) in \(booking.address.suburb)"
        let moneyWord: String?
        switch booking.status {
        case .done: moneyWord = "to pay"
        case .paid: moneyWord = "paid"
        case .cancelledByClient, .cancelledByPro, .declined, .noShow: moneyWord = nil
        default: moneyWord = "held"
        }
        var lines = Text(verbatim: "\(when)\n\(whereLine)\n\(booking.servicesLine)").foregroundStyle(Palette.ink)
        if let moneyWord {
            // The words stay serif; the amount is SF at the same size (money is never serif).
            lines = lines
                + Text(verbatim: " · ").foregroundStyle(Palette.ink)
                + Text(verbatim: Money.format(booking.price.clientTotalCents))
                    .font(HDFont.sans(19, relativeTo: .body).monospacedDigit())
                    .foregroundStyle(Palette.ink)
                + Text(verbatim: " \(moneyWord)").foregroundStyle(Palette.ink)
        }
        let stopColor = booking.status == .done ? Palette.ink : Palette.lacquer
        return lines + Text(verbatim: ".").foregroundStyle(stopColor)
    }

    private func statusLine(_ booking: Booking, proName: String) -> String {
        if booking.status == .done {
            return "Done. Pay \(proName) now, or we'll charge your card at \(booking.autoChargeAt.clock)."
        }
        return booking.status.clientLine(pro: proName)
    }

    // MARK: What she can do

    @ViewBuilder
    private func actions(_ booking: Booking, pro: Pro?, proName: String) -> some View {
        VStack(spacing: Space.s) {
            switch booking.status {
            case .requested, .confirmed:
                messageButton(booking, proName: proName)
                OutlineButton(title: "Reschedule", isEnabled: !app.isOffline) { showReschedule = true }
                cancelLink(booking)

            case .onHerWay, .arrived, .inProgress:
                messageButton(booking, proName: proName)
                ShareLink(item: booking.shareText(proName: proName)) {
                    outlineLabel("Share with a friend")
                }
                .buttonStyle(PressLift())
                .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
                if booking.clientCanCancel { cancelLink(booking) }

            case .done:
                PrimaryButton(title: "Pay \(Money.format(booking.price.clientTotalCents))", isEnabled: !app.isOffline) { showPay = true }
                TertiaryButton(title: "Something wrong?") { confirmFlag = true }
                    .disabled(app.isOffline)

            case .paid:
                if booking.review == nil {
                    InkButton(title: "Rate \(proName)") { showReview = true }
                }

            case .cancelledByClient, .cancelledByPro, .declined, .noShow:
                EmptyView()
            }
        }
    }

    private func cancelLink(_ booking: Booking) -> some View {
        TertiaryButton(title: "Cancel booking") {
            cancelProblem = nil
            showCancel = true
        }
        .disabled(app.isOffline)
        .accessibilityHint(booking.cancelChargeCents > 0 ? "Costs \(Money.format(booking.cancelChargeCents))" : "Free")
    }

    @ViewBuilder
    private func messageButton(_ booking: Booking, proName: String) -> some View {
        if let thread = app.thread(for: booking) {
            NavigationLink(value: Route.thread(thread.id)) {
                Text("Message \(proName)")
                    .font(HDFont.bodyStrong)
                    .foregroundStyle(Palette.paper)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.l)
                    .padding(.vertical, Space.m)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Palette.ink, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            }
            .buttonStyle(PressLift())
            .simultaneousGesture(TapGesture().onEnded { Haptics.medium() })
        }
    }

    private func outlineLabel(_ title: String) -> some View {
        Text(title)
            .font(HDFont.bodyStrong)
            .foregroundStyle(Palette.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.m)
            .frame(maxWidth: .infinity, minHeight: 52)
            .overlay(RoundedRectangle(cornerRadius: Radius.button, style: .continuous).strokeBorder(Palette.ink, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
    }

    // MARK: Where it's up to

    private func timeline(_ booking: Booking, pro: Pro?) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Where it's up to").labelStyle()
            BookingTimeline(booking: booking, pro: pro)
        }
    }

    // MARK: Receipt

    private func receipt(_ booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("The details").labelStyle().padding(.bottom, Space.s)
            row("When", value: booking.start.friendlyDayTime,
                note: "Till about \(booking.end.clock) · \(booking.minutes.minutesLabel)")
            if booking.status.isCancelled {
                ForEach(booking.services) { s in
                    row(s.name, value: "", note: s.durationLabel)
                }
            } else {
                ForEach(booking.services) { s in
                    row(s.name, value: Money.format(s.priceCents), note: s.durationLabel, money: true)
                }
                row("Travel fee", value: Money.format(booking.price.travelFeeCents), money: true)
                row("Booking fee", value: Money.format(booking.price.bookingFeeCents), money: true)
            }
            if booking.price.tipCents > 0 {
                row("Tip", value: Money.format(booking.price.tipCents), note: "All of it went to her", money: true)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(totalLabel(booking)).font(HDFont.body).foregroundStyle(Palette.ink)
                Spacer(minLength: Space.m)
                Text(Money.format(chargedCents(booking))).font(HDFont.priceTotal).foregroundStyle(Palette.ink)
            }
            .padding(.top, Space.m)
            .accessibilityElement(children: .combine)
        }
    }

    /// What she pays, or paid. A cancelled booking only costs what the cancellation charged:
    /// for her own late cancel the price is already just that charge; a no-show is the full
    /// price; anything she didn't cancel costs nothing.
    private func chargedCents(_ booking: Booking) -> Int {
        switch booking.status {
        case .cancelledByClient, .noShow: return booking.price.clientTotalCents
        case .cancelledByPro, .declined: return 0
        default: return booking.price.clientTotalCents
        }
    }

    private func totalLabel(_ booking: Booking) -> String {
        if booking.status.isCancelled { return chargedCents(booking) > 0 ? "Charged" : "Nothing charged" }
        return booking.status == .paid ? "Paid" : "Total"
    }

    private func row(_ label: String, value: String, note: String? = nil, money: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if let note {
                    Text(note).font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Space.s)
            Text(value)
                .font(money ? HDFont.price : HDFont.body)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, Space.m)
        .overlay(alignment: .bottom) { Hairline(strong: true) }
        .accessibilityElement(children: .combine)
    }

    // MARK: Where

    private func whereSection(_ booking: Booking) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: booking.address.latitude, longitude: booking.address.longitude)
        return VStack(alignment: .leading, spacing: Space.s) {
            Text("Where").labelStyle()
            Text(booking.address.full).font(HDFont.body).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !booking.address.instructions.isEmpty {
                Text(booking.address.instructions).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 900, longitudinalMeters: 900))) {
                Marker(booking.address.label, coordinate: coordinate).tint(Palette.ink)
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .allowsHitTesting(false)
            .frame(height: 160)
            .photoShape()
            .padding(.top, Space.xs)
            .accessibilityLabel("Map of \(booking.address.short)")
            Button {
                Haptics.light()
                let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                item.name = booking.address.label
                item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
            } label: {
                HStack(spacing: 6) {
                    Text("Open in Maps").font(HDFont.subMedium)
                    Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .regular))
                }
                .foregroundStyle(Palette.ink)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens Apple Maps")
        }
    }

    // MARK: Notes and photos

    /// Her own photos (signed URLs). The seed tiles are the demo's stand-ins, so they only show on
    /// the mock backend: on live, a bundled photo is never shown as hers.
    private func hasPhotos(_ booking: Booking) -> Bool {
        !booking.inspoURLs.isEmpty || (!app.isLive && !booking.inspoSeeds.isEmpty)
    }

    private func notesSection(_ booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            if !booking.notes.isEmpty {
                Text("Notes").labelStyle()
                Text(booking.notes).font(HDFont.italicSub).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
            }
            if hasPhotos(booking) {
                Text("Your photos").labelStyle().padding(.top, booking.notes.isEmpty ? 0 : Space.s)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.s) {
                        if !booking.inspoURLs.isEmpty {
                            ForEach(Array(booking.inspoURLs.enumerated()), id: \.offset) { i, url in
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    SkeletonBlock(width: 104, height: 130)
                                }
                                .frame(width: 104, height: 130)
                                .clipped()
                                .photoShape()
                                .accessibilityLabel("Inspo photo \(i + 1)")
                            }
                        } else {
                            ForEach(Array(booking.inspoSeeds.enumerated()), id: \.offset) { i, seed in
                                WorkTile(item: WorkItem(id: "inspo_\(booking.id)_\(i)", category: booking.primaryCategory, caption: "Inspo photo \(i + 1)", seed: seed), cornerRadius: Radius.photo)
                                    .frame(width: 104, height: 130)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Your review

    private func reviewSection(_ review: Review, proName: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text("What you said").labelStyle()
                Spacer()
                Text(review.date.shortDay).font(HDFont.caption).foregroundStyle(Palette.inkSoft)
            }
            StarsRow(rating: review.rating, size: 14)
            if !review.text.isEmpty {
                Text(review.text).font(HDFont.quote).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
            }
            if let reply = review.proReply, !reply.isEmpty {
                Text("\(proName) replied").labelStyle().padding(.top, Space.s)
                Text(reply).font(HDFont.sub).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: After

    @ViewBuilder
    private func after(_ booking: Booking, pro: Pro?, proName: String) -> some View {
        if booking.status.isFinished || booking.status.isCancelled {
            VStack(alignment: .leading, spacing: Space.s) {
                if let pro {
                    NavigationLink(value: Route.pro(pro)) { outlineLabel("Book \(proName) again") }
                        .buttonStyle(PressLift())
                        .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
                }
                if booking.status == .paid {
                    Button {
                        Haptics.light()
                        showReceipt = true
                    } label: {
                        Text("Get receipt").font(HDFont.subMedium).foregroundStyle(Palette.ink)
                            .frame(minHeight: 44)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: Cancel

    private func cancelSheet(_ booking: Booking, proName: String) -> some View {
        ConfirmSheet(title: "Cancel this booking?",
                     message: booking.cancelBody(proName: proName),
                     confirmTitle: booking.cancelButtonTitle,
                     cancelTitle: "Keep it",
                     isWorking: cancelling,
                     onConfirm: { cancel(booking, proName: proName) },
                     onCancel: { showCancel = false }) {
            VStack(alignment: .leading, spacing: Space.s) {
                if booking.cancelChargeCents > 0 {
                    HStack(alignment: .firstTextBaseline) {
                        Text("You'll pay").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        Spacer()
                        Text(Money.format(booking.cancelChargeCents)).font(HDFont.priceTotal).foregroundStyle(Palette.ink)
                    }
                    .accessibilityElement(children: .combine)
                }
                if let cancelProblem { FieldMessage(text: cancelProblem) }
            }
        }
        .confirmSheetPresentation()
        .holdsPushRoutes()
    }

    private func cancel(_ booking: Booking, proName: String) {
        guard !cancelling else { return }
        cancelling = true
        cancelProblem = nil
        let line = booking.cancelDoneLine(proName: proName)
        Task { @MainActor in
            let done = await app.update(booking, to: .cancelledByClient) != nil
            cancelling = false
            if done {
                showCancel = false
                app.show(line)
            } else {
                cancelProblem = app.lastError ?? "That didn't go through. Nothing's changed. Try again."
            }
        }
    }

    // MARK: Simulate (debug only)

    /// Walks a booking along the happy path so the timeline can be shown off. Not in release builds.
    @ViewBuilder
    private func simulateMenu(_ booking: Booking) -> some View {
        #if DEBUG
        // Sample data only: the real server won't let a client move her own booking along.
        if !app.isLive {
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
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Simulate")
        }
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

/// requested → confirmed → on her way → here → done → paid, in ink. Reached dots are solid ink,
/// the current one sits in a `line` ring, future ones are hollow. A cancelled or declined booking
/// ends on its own step with the reason.
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
                        dot(reached: reached, current: isCurrent)
                        if !isLast {
                            Rectangle()
                                .fill(Palette.line)
                                .frame(width: 1)
                                .frame(minHeight: 18)
                        }
                    }
                    .frame(width: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(step.timelineTitle)
                                .font(isCurrent ? HDFont.bodyStrong : HDFont.body)
                                .foregroundStyle(reached ? Palette.ink : Palette.inkSoft)
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
                .accessibilityLabel("\(step.timelineTitle)\(reached ? "" : ", not yet")\(isCurrent ? ", now" : "")")
            }
        }
    }

    private func dot(reached: Bool, current: Bool) -> some View {
        ZStack {
            if current {
                Circle().strokeBorder(Palette.line, lineWidth: 1).frame(width: 16, height: 16)
            }
            if reached {
                Circle().fill(Palette.ink).frame(width: 8, height: 8)
            } else {
                Circle().strokeBorder(Palette.line, lineWidth: 1).frame(width: 8, height: 8)
            }
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
            return "See you \(booking.start.hdSpokenDay.replacingOccurrences(of: "on ", with: "")) at \(booking.start.clock)."
        case .onHerWay:
            if let pro { return "About \(booking.travelMinutes(from: pro)) minutes out." }
            return "She's on the road."
        case .arrived:
            return booking.status == .inProgress ? "Happening now." : "Put the kettle on."
        case .done:
            return "Pay now, or it's charged at \(booking.autoChargeAt.clock)."
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

#Preview("Tonight, confirmed") {
    NavigationStack { BookingDetailView(bookingID: "bk_1") }.environment(previewApp())
}

#Preview("Paid, rated") {
    NavigationStack { BookingDetailView(bookingID: "bk_4") }.environment(previewApp())
}

#Preview("Cancelled") {
    NavigationStack { BookingDetailView(bookingID: "bk_7") }.environment(previewApp())
}
