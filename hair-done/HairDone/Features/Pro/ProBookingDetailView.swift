import SwiftUI
import MapKit

/// One job, from her side. Where, when, what she gets, and the one button for what's next.
struct ProBookingDetailView: View {
    @Environment(AppState.self) private var app
    var bookingID: String
    @State private var declining: Booking? = nil
    @State private var confirmCancel = false
    @State private var cancelling = false

    private var booking: Booking? { app.proBookings.first { $0.id == bookingID } }

    var body: some View {
        Group {
            if let b = booking {
                content(b)
            } else {
                EmptyState(symbol: "calendar.badge.exclamationmark", title: "We couldn't find that one.", message: "Pull down on Today to refresh.")
                    .paperBackground()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.paper, for: .navigationBar)
    }

    private func content(_ b: Booking) -> some View {
        let client = app.clientName(b.clientID)
        let addressShown = b.status != .requested
        return ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                // Who and what state
                VStack(alignment: .leading, spacing: Space.m) {
                    HStack(alignment: .top, spacing: Space.m) {
                        Avatar(name: client, seed: ProFlow.seed(for: b.clientID), size: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(client).font(HDFont.title).foregroundStyle(Palette.ink)
                            Text(b.reference).font(HDFont.caption).foregroundStyle(Palette.inkSoft).monospacedDigit()
                        }
                        Spacer()
                        StatusBadge(status: b.status)
                    }
                    Text(b.status.proLine(client: client)).font(HDFont.body).foregroundStyle(Palette.ink)
                    if let reason = b.declineReason, b.status == .declined {
                        Text("You said: \(reason)").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    }
                }

                // The one button
                if b.status == .requested {
                    VStack(alignment: .leading, spacing: Space.s) {
                        HStack(spacing: Space.s) {
                            PrimaryButton(title: "Accept") { Task { await accept(b) } }
                            SecondaryButton(title: "Decline") { declining = b }
                        }
                        Text(ProFlow.autoDeclineLine(for: b)).font(HDFont.caption).foregroundStyle(Palette.warn)
                    }
                } else {
                    StatusActionButton(booking: b, clientName: client)
                }

                // When
                section("When") {
                    HStack(alignment: .firstTextBaseline) {
                        Text(b.start.friendlyDayTime).font(HDFont.heading).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(b.minutes.minutesLabel) · till \(b.end.clock)").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    }
                }

                // Where
                section("Where") {
                    VStack(alignment: .leading, spacing: Space.m) {
                        if addressShown {
                            Text(b.address.full).font(HDFont.body).foregroundStyle(Palette.ink)
                            if !b.address.instructions.isEmpty {
                                Text(b.address.instructions).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                            }
                            mapCard(b, client: client)
                        } else {
                            Text(b.address.suburb).font(HDFont.body).foregroundStyle(Palette.ink)
                            Text("Full address once you accept.").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        }
                    }
                }

                // What and money
                section("What") {
                    VStack(alignment: .leading, spacing: Space.s) {
                        ForEach(b.services) { s in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.name).font(HDFont.body).foregroundStyle(Palette.ink)
                                    Text(s.durationLabel).font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                                }
                                Spacer()
                                Text(s.priceLabel).font(HDFont.price).foregroundStyle(Palette.ink)
                            }
                            .accessibilityElement(children: .combine)
                        }
                        PriceRow(label: "Travel fee", cents: b.price.travelFeeCents)
                        Hairline().padding(.vertical, 4)
                        Text("Your payout").labelStyle()
                        HStack {
                            Text("Hair Done fee, 12%").font(HDFont.body).foregroundStyle(Palette.ink)
                            Spacer()
                            Text("−" + Money.format(b.price.platformFeeCents)).font(HDFont.price).foregroundStyle(Palette.inkSoft)
                        }
                        .accessibilityElement(children: .combine)
                        if b.price.tipCents > 0 {
                            HStack {
                                Text("Tip").font(HDFont.body).foregroundStyle(Palette.ink)
                                Spacer()
                                Text("+" + Money.format(b.price.tipCents)).font(HDFont.price).foregroundStyle(Palette.success)
                            }
                            .accessibilityElement(children: .combine)
                        }
                        PriceRow(label: "To you", cents: b.price.proPayoutCents, emphasis: true)
                        Text("The $3 booking fee is paid by the client, not you.").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    }
                }

                // Notes and inspo
                if !b.notes.isEmpty || !b.inspoSeeds.isEmpty {
                    section("Her notes") {
                        VStack(alignment: .leading, spacing: Space.m) {
                            if !b.notes.isEmpty { Text(b.notes).font(HDFont.body).foregroundStyle(Palette.ink) }
                            if !b.inspoSeeds.isEmpty {
                                HStack(spacing: Space.s) {
                                    ForEach(Array(b.inspoSeeds.prefix(3).enumerated()), id: \.offset) { i, seed in
                                        WorkTile(item: WorkItem(id: "inspo_\(b.id)_\(i)", category: b.primaryCategory, caption: "Inspo photo \(i + 1)", seed: seed))
                                            .aspectRatio(1, contentMode: .fit)
                                    }
                                }
                            }
                        }
                    }
                }

                // Message
                if let thread = app.thread(for: b) {
                    NavigationLink(value: Route.thread(thread.id)) {
                        HStack(spacing: 8) {
                            Image(systemName: "bubble.left")
                            Text("Message \(client)")
                        }
                        .font(HDFont.bodyStrong)
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Palette.card, in: Capsule())
                        .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
                    }
                    .buttonStyle(PressLift())
                }

                // Cancel, quietly
                if [.confirmed, .onHerWay, .arrived].contains(b.status) {
                    VStack(spacing: 2) {
                        TertiaryButton(title: cancelling ? "Cancelling" : "Cancel this booking") { confirmCancel = true }
                        Text("She gets a full refund and your reliability drops.").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .confirmationDialog("Cancel on \(client)?", isPresented: $confirmCancel, titleVisibility: .visible) {
                        Button("Cancel the booking", role: .destructive) { Task { await cancel(b) } }
                        Button("Keep it", role: .cancel) {}
                    } message: {
                        Text("\(client) is refunded in full and told straight away. Your reliability score drops, and clients see it.")
                    }
                }
            }
            .screenGutter()
            .padding(.vertical, Space.l)
        }
        .paperBackground()
        .sheet(item: $declining) { b in DeclineSheet(booking: b, clientName: client) }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(title).labelStyle()
            content()
        }
    }

    private func mapCard(_ b: Booking, client: String) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: b.address.latitude, longitude: b.address.longitude)
        let region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012))
        return Button {
            Haptics.light()
            openDirections(to: b.address)
        } label: {
            Map(initialPosition: .region(region)) {
                Marker(client, coordinate: coordinate).tint(Palette.lacquer)
            }
            .allowsHitTesting(false)
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond")
                    Text("Directions")
                }
                .font(HDFont.subStrong)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Palette.paper.opacity(0.94), in: Capsule())
                .padding(10)
            }
        }
        .buttonStyle(PressLift(scale: 0.985))
        .accessibilityLabel("Directions to \(b.address.short)")
        .accessibilityHint("Opens Maps")
    }

    private func openDirections(to address: Address) {
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: address.latitude, longitude: address.longitude))
        let item = MKMapItem(placemark: placemark)
        item.name = address.short
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func accept(_ b: Booking) async {
        if await app.update(b, to: .confirmed) != nil {
            Haptics.success()
            app.show("Confirmed. She's been told.")
        }
    }

    private func cancel(_ b: Booking) async {
        cancelling = true
        defer { cancelling = false }
        if await app.update(b, to: .cancelledByPro) != nil {
            app.show("Cancelled. She's been refunded in full.")
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
