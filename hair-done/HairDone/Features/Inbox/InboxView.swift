import SwiftUI

/// Threads, one per booking. The same screen on both sides; only who's "the other person" changes.
struct InboxView: View {
    @Environment(AppState.self) private var app

    private var sortedThreads: [MessageThread] {
        app.threads.sorted { ($0.last?.sentAt ?? .distantPast) > ($1.last?.sentAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Inbox")
                        .font(HDFont.hero)
                        .foregroundStyle(Palette.ink)
                        .padding(.top, Space.s)
                        .padding(.bottom, Space.l)
                        .accessibilityAddTraits(.isHeader)

                    if sortedThreads.isEmpty {
                        EmptyState(symbol: "bubble.left", title: "No messages yet.", message: "Threads show up here once you've booked.")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(sortedThreads) { thread in
                                ThreadRow(thread: thread, booking: booking(for: thread))
                                if thread.id != sortedThreads.last?.id { Hairline().padding(.leading, 68) }
                            }
                        }
                        .card(padding: 0)
                    }
                }
                .screenGutter()
                .padding(.bottom, Space.section)
            }
            .paperBackground()
            .refreshable { await app.loadThreads() }
            .task { if app.isLive { await app.loadThreads() } }
            .toolbar(.hidden, for: .navigationBar)
            .hdDestinations()
        }
    }

    private func booking(for thread: MessageThread) -> Booking? {
        app.bookings.first { $0.id == thread.bookingID } ?? app.proBookings.first { $0.id == thread.bookingID }
    }
}

/// One thread: who, what they last said, when, and a lacquer dot if you haven't read it.
struct ThreadRow: View {
    @Environment(AppState.self) private var app
    var thread: MessageThread
    var booking: Booking?

    private var isPro: Bool { app.mode == .pro }
    private var name: String {
        isPro ? app.clientName(thread.clientID) : (app.pro(thread.proID)?.firstName ?? "Her")
    }
    private var seed: Int {
        isPro ? thread.clientID.hdSeed : (app.pro(thread.proID)?.seed ?? 0)
    }
    private var unread: Int { isPro ? thread.unreadForPro : thread.unreadForClient }
    private var preview: String {
        guard let last = thread.last else { return "No messages yet" }
        if last.isSystem { return last.text }
        let mine = last.senderID == app.userID
        return mine ? "You: \(last.text)" : last.text
    }
    private var caption: String? {
        guard let booking else { return nil }
        return "\(booking.servicesLine) · \(booking.start.friendlyDay)"
    }

    var body: some View {
        NavigationLink(value: Route.thread(thread.id)) {
            HStack(alignment: .top, spacing: Space.m) {
                Avatar(name: name, seed: seed, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(name).font(unread > 0 ? HDFont.bodyStrong : HDFont.body).foregroundStyle(Palette.ink)
                        Spacer(minLength: Space.s)
                        if let at = thread.last?.sentAt {
                            Text(at.hdRelative).font(HDFont.caption).foregroundStyle(unread > 0 ? Palette.lacquer : Palette.inkSoft)
                        }
                    }
                    Text(preview)
                        .font(HDFont.sub)
                        .foregroundStyle(unread > 0 ? Palette.ink : Palette.inkSoft)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let caption {
                        Text(caption).font(HDFont.caption).foregroundStyle(Palette.inkFaint).lineLimit(1)
                    }
                }
                if unread > 0 {
                    Circle().fill(Palette.lacquer).frame(width: 9, height: 9).padding(.top, 6)
                        .accessibilityHidden(true)
                }
            }
            .padding(Space.cardPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressLift(scale: 0.99))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name)\(unread > 0 ? ", unread" : ""). \(preview)\(caption.map { ". \($0)" } ?? "")")
        .accessibilityHint("Opens the conversation")
    }
}

#Preview("Client inbox") {
    InboxView().environment(previewApp())
}

#Preview("Pro inbox") {
    InboxView().environment(previewApp(mode: .pro))
}

#Preview("Empty") {
    let app = previewApp()
    app.threads = []
    return InboxView().environment(app)
}
