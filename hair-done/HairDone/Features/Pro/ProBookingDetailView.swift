import SwiftUI
import MapKit

/// One job, from her side. Who and when as a headline, where on a map, what she gets as a receipt,
/// and the one button for what's next.
struct ProBookingDetailView: View {
    @Environment(AppState.self) private var app
    var bookingID: String
    @State private var declining: Booking? = nil
    @State private var accepting = false
    @State private var confirmCancel = false
    @State private var cancelling = false

    private var booking: Booking? { app.proBookings.first { $0.id == bookingID } }

    var body: some View {
        Group {
            if let b = booking {
                content(b)
            } else if app.proSideLoadFailed {
                ScrollView { ErrorState { Task { await app.loadProSide() } } }
            } else if app.isLoadingProSide {
                ListSkeleton(rows: 2).padding(.top, Space.l)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView {
                    EmptyState(title: "We couldn't find that one.", message: "It may have been cancelled.")
                }
            }
        }
        .paperBackground()
        .hdNavHeader()
        // Opened from a notification or a link before her jobs were in: look for it once.
        .task(id: bookingID) {
            if booking == nil && !app.isLoadingProSide { await app.loadProSide() }
        }
    }

    private func content(_ b: Booking) -> some View {
        // Empty while her name's on its way; the header shows a shimmer and sentences say "your client".
        let client = app.clientName(b.clientID)
        let known = app.isClientNameKnown(b.clientID)
        let addressShown = b.status != .requested
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if app.isOffline { OfflineBar().padding(.horizontal, -Space.gutter) }

                // Who, when, what state
                VStack(alignment: .leading, spacing: Space.s) {
                    StatusBadge(status: b.status, forPro: true)
                    if known {
                        Text("\(client), \(b.start.clock).")
                            .font(HDFont.title).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    } else {
                        HStack(alignment: .center, spacing: Space.s) {
                            SkeletonBlock(width: 120, height: 30)
                            Text("\(b.start.clock).")
                                .font(HDFont.title).foregroundStyle(Palette.ink)
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                    Text("\(ProFlow.longDay(b.start)) · \(b.minutes.minutesLabel), till \(b.end.clock)")
                        .font(HDFont.quote).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(b.status.proLine(client: ProFlow.whoLead(client))).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    if let reason = b.declineReason, b.status == .declined {
                        Text("You said: \(reason)").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    }
                    Text(b.reference).font(HDFont.caption).foregroundStyle(Palette.inkSoft).monospacedDigit()
                }
                .padding(.top, Space.l)

                // The one button
                VStack(alignment: .leading, spacing: Space.s) {
                    if b.status == .requested {
                        HStack(spacing: Space.s) {
                            InkButton(title: "Accept", isLoading: accepting, isEnabled: !app.isOffline) { Task { await accept(b) } }
                            OutlineButton(title: "Decline", isEnabled: !app.isOffline) { declining = b }
                        }
                        WarnDotLine(text: "\(ProFlow.timeLeft(b)). After that it goes to someone else and counts against you.", font: HDFont.caption)
                    } else {
                        StatusActionButton(booking: b, clientName: client)
                    }
                }
                .padding(.top, Space.xl)

                // Where
                section("Where") {
                    if addressShown {
                        Text(b.address.full).font(HDFont.body).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if !b.address.instructions.isEmpty {
                            Text(b.address.instructions).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        }
                        map(b).padding(.top, Space.xs)
                        Button {
                            Haptics.light()
                            openDirections(to: b.address)
                        } label: {
                            HStack(spacing: 6) {
                                Text("Directions")
                                Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .regular))
                            }
                            .font(HDFont.subMedium).foregroundStyle(Palette.ink)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens Maps")
                    } else {
                        Text(b.address.suburb).font(HDFont.body).foregroundStyle(Palette.ink)
                        Text("Full address once you accept.").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    }
                }

                // What she gets
                section("What and what you get") {
                    VStack(spacing: 0) {
                        ForEach(b.services) { s in
                            receiptRow(s.name, sub: s.durationLabel, value: s.priceLabel)
                        }
                        if b.price.travelFeeCents > 0 {
                            receiptRow("Travel fee", value: Money.format(b.price.travelFeeCents))
                        }
                        receiptRow("Hair Done's 12%", value: "−" + Money.format(b.price.platformFeeCents), soft: true)
                        if b.price.tipCents > 0 {
                            receiptRow("Tip", sub: "All yours, no fee.", value: "+" + Money.format(b.price.tipCents))
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text("To you").font(HDFont.bodyStrong).foregroundStyle(Palette.ink)
                            Spacer()
                            Text(Money.format(b.price.proPayoutCents)).font(HDFont.priceTotal).foregroundStyle(Palette.ink)
                        }
                        .padding(.top, Space.m)
                        .accessibilityElement(children: .combine)
                    }
                    Text("The $3 booking fee is paid by the client, not you.")
                        .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                }

                // Notes and inspo
                if !b.notes.isEmpty || !b.inspoSeeds.isEmpty || !b.inspoURLs.isEmpty {
                    section("Her notes") {
                        if !b.notes.isEmpty {
                            Text("“\(b.notes)”").font(HDFont.quote).italic().foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        inspo(b)
                    }
                }

                // Message and cancel
                VStack(alignment: .leading, spacing: Space.s) {
                    if let thread = app.thread(for: b) {
                        NavigationLink(value: Route.thread(thread.id)) {
                            Text("Message \(ProFlow.who(client))")
                                .font(HDFont.bodyStrong).foregroundStyle(Palette.ink)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .overlay(RoundedRectangle(cornerRadius: Radius.button, style: .continuous).strokeBorder(Palette.ink, lineWidth: 1))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressLift())
                    }
                    if [.confirmed, .onHerWay, .arrived].contains(b.status) {
                        TertiaryButton(title: cancelling ? "Cancelling" : "Cancel this booking") { confirmCancel = true }
                            .padding(.leading, -8)
                            .disabled(app.isOffline || cancelling)
                        Text("\(ProFlow.whoLead(client)) gets a full refund and your reliability drops.")
                            .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    }
                }
                .padding(.top, Space.section)
            }
            .screenGutter()
            .padding(.bottom, Space.section)
        }
        .refreshable { await app.loadProSide() }
        .sheet(item: $declining) { b in DeclineSheet(booking: b, clientName: client) }
        .confirmSheet(isPresented: $confirmCancel,
                      title: "Cancel on \(ProFlow.who(client))?",
                      message: "\(ProFlow.whoLead(client)) is refunded in full and told straight away. Your reliability drops. We see it, clients don't.",
                      confirmTitle: "Cancel the booking",
                      cancelTitle: "Keep it") {
            Task { await cancel(b) }
        }
    }

    // MARK: Pieces

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(title).labelStyle()
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Space.section)
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

    @ViewBuilder
    private func inspo(_ b: Booking) -> some View {
        if !b.inspoURLs.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(Array(b.inspoURLs.enumerated()), id: \.offset) { i, url in
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Palette.photoGround
                        }
                        .frame(width: 104, height: 130)
                        .clipped()
                        .photoShape()
                        .accessibilityLabel("Inspo photo \(i + 1)")
                    }
                }
            }
        } else if !b.inspoSeeds.isEmpty && !app.isLive {
            // Sample data only: seeded stand-ins. A real booking's inspo is always her own photos.
            HStack(spacing: Space.s) {
                ForEach(Array(b.inspoSeeds.prefix(3).enumerated()), id: \.offset) { i, seed in
                    WorkTile(item: WorkItem(id: "inspo_\(b.id)_\(i)", category: b.primaryCategory, caption: "Inspo photo \(i + 1)", seed: seed), cornerRadius: Radius.photo)
                        .frame(width: 104, height: 130)
                }
            }
        }
    }

    private func map(_ b: Booking) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: b.address.latitude, longitude: b.address.longitude)
        let region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012))
        return Map(initialPosition: .region(region), interactionModes: []) {
            Annotation("", coordinate: coordinate) {
                Circle().fill(Palette.ink).frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(Palette.paper, lineWidth: 1.5))
            }
        }
        .frame(height: 170)
        .photoShape()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map of \(b.address.short)")
    }

    private func openDirections(to address: Address) {
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: address.latitude, longitude: address.longitude))
        let item = MKMapItem(placemark: placemark)
        item.name = address.short
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func accept(_ b: Booking) async {
        accepting = true
        defer { accepting = false }
        if await app.update(b, to: .confirmed) != nil {
            Haptics.success()
            app.show("Booked. \(ProFlow.whoLead(app.clientName(b.clientID)))'s \(b.start.friendlyDay) at \(b.start.clock).")
        }
    }

    private func cancel(_ b: Booking) async {
        cancelling = true
        defer { cancelling = false }
        if await app.update(b, to: .cancelledByPro) != nil {
            app.show("Cancelled. \(ProFlow.whoLead(app.clientName(b.clientID)))'s been refunded in full.")
        }
    }
}

#Preview("Confirmed, tonight") {
    NavigationStack { ProBookingDetailView(bookingID: "pb_3").hdDestinations() }
        .environment(previewApp(mode: .pro))
}

#Preview("Request") {
    NavigationStack { ProBookingDetailView(bookingID: "pb_4").hdDestinations() }
        .environment(previewApp(mode: .pro))
}
