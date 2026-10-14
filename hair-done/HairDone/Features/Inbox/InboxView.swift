import SwiftUI

/// Threads, one per booking. The same screen on both sides; only who's "the other person" changes.
/// Each side shows its own threads; if the other side has unread ones, a line at the top says so.
struct InboxView: View {
    @Environment(AppState.self) private var app
    @State private var path = NavigationPath()
    /// False until the first load here comes back, so the live backend shows rows loading first.
    @State private var loaded = false

    private var isPro: Bool { app.mode == .pro }

    private var sortedThreads: [MessageThread] {
        app.threads.sorted { ($0.last?.sentAt ?? .distantPast) > ($1.last?.sentAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .screenGutter()
                        .padding(.top, Space.s)
                        .padding(.bottom, Space.l)

                    if app.isOffline { OfflineBar().padding(.bottom, Space.s) }
                    if app.otherSideUnreadCount > 0 { otherSideLine }

                    if app.isLive && !loaded && app.threads.isEmpty {
                        ListSkeleton(rows: 4)
                    } else if sortedThreads.isEmpty {
                        if app.threadsLoadFailed {
                            ErrorState { Task { await app.loadThreads() } }
                        } else if isPro {
                            EmptyState(title: "Quiet in here.", message: "Messages with clients show up once someone books you.")
                        } else {
                            EmptyState(title: "No messages yet.", message: "Threads show up here once you've booked.",
                                       actionTitle: "See who's free") { app.selectedTab = .home }
                        }
                    } else {
                        if app.threadsLoadFailed {
                            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                                FieldMessage(text: "Couldn't refresh. This is what we had.")
                                Spacer(minLength: 0)
                                TertiaryButton(title: "Try again", tint: Palette.ink) { Task { await app.loadThreads() } }
                            }
                            .screenGutter()
                        }
                        VStack(spacing: 0) {
                            ForEach(sortedThreads) { thread in
                                ThreadRow(thread: thread, booking: booking(for: thread))
                            }
                        }
                        .screenGutter()
                    }
                }
                .padding(.bottom, Space.section)
            }
            .paperBackground()
            .refreshable { await app.loadThreads() }
            .task {
                if app.isLive && !loaded { await app.loadThreads() }
                loaded = true
            }
            .toolbar(.hidden, for: .navigationBar)
            .hdDestinations()
            .animation(Motion.gentle, value: app.isOffline)
        }
        .receivesPendingRoutes($path) { $0.isThread }
    }

    // MARK: Header

    private var unread: Int { app.unreadCount }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            if isPro, let me = app.proSelf {
                ProEyebrow(name: me.displayName, detail: unread > 0 ? "\(unread) unread" : nil)
            } else {
                Text(unread > 0 ? "\(unread) unread" : "All read").labelStyle()
            }
            Text("Inbox.")
                .font(HDFont.display)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// "1 unread in Pro mode   Switch". The other side's threads are never shown here, only counted.
    private var otherSideLine: some View {
        let n = app.otherSideUnreadCount
        let side = isPro ? "Booking mode" : "Pro mode"
        return HStack(alignment: .center, spacing: Space.s) {
            Circle().fill(Palette.lacquer).frame(width: 8, height: 8).accessibilityHidden(true)
            Text("\(n) unread in \(side)")
                .font(HDFont.sub)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Space.s)
            TertiaryButton(title: "Switch", tint: Palette.ink) {
                app.switchMode(isPro ? .client : .pro)
                if isPro { app.selectedTab = .inbox } else { app.selectedProTab = .inbox }
            }
            .padding(.trailing, -8)
            .accessibilityLabel("Switch to \(side)")
        }
        .padding(.vertical, Space.xs)
        .overlay(alignment: .bottom) { Hairline(strong: true) }
        .screenGutter()
        .padding(.bottom, Space.s)
        .accessibilityElement(children: .combine)
    }

    private func booking(for thread: MessageThread) -> Booking? {
        app.bookings.first { $0.id == thread.bookingID } ?? app.proBookings.first { $0.id == thread.bookingID }
    }
}

/// One thread: who, what they last said, when, and a lacquer dot if you haven't read it.
/// A hairline row; the hairline sits under the text column.
struct ThreadRow: View {
    @Environment(AppState.self) private var app
    var thread: MessageThread
    var booking: Booking?

    private var isPro: Bool { app.mode == .pro }
    /// On the pro side, a client's name that hasn't come back yet shows as a shimmer, not "Client".
    private var nameMissing: Bool {
        isPro && app.isLive && (app.clientNames[thread.clientID]?.isEmpty ?? true)
    }
    private var name: String {
        isPro ? app.clientName(thread.clientID) : (app.pro(thread.proID)?.firstName ?? "Her")
    }
    private var otherPro: Pro? { isPro ? nil : app.pro(thread.proID) }
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
                Avatar(name: name, seed: isPro ? thread.clientID.hdSeed : (otherPro?.seed ?? 0), size: 44,
                       photo: otherPro.flatMap { p in p.work.first(where: { $0.isPinned }) ?? p.work.first })
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        if nameMissing {
                            SkeletonBlock(width: 90, height: 16).padding(.top, 2)
                        } else {
                            Text(name)
                                .font(HDFont.nameSmall)
                                .foregroundStyle(unread > 0 ? Palette.ink : Palette.ink.opacity(0.85))
                                .lineLimit(1)
                        }
                        Spacer(minLength: Space.s)
                        if let at = thread.last?.sentAt {
                            Text(at.hdRelative).font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                        }
                        if unread > 0 {
                            Circle().fill(Palette.lacquer).frame(width: 8, height: 8)
                                .accessibilityHidden(true)
                        }
                    }
                    Text(preview)
                        .font(unread > 0 ? HDFont.subMedium : HDFont.sub)
                        .foregroundStyle(unread > 0 ? Palette.ink : Palette.inkSoft)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let caption {
                        Text(caption).font(HDFont.caption).foregroundStyle(Palette.inkSoft).lineLimit(1)
                    }
                }
                .padding(.bottom, Space.m)
                .overlay(alignment: .bottom) { Hairline(strong: true) }
            }
            .padding(.top, Space.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressLift(scale: 0.99))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(nameMissing ? "Client" : name)\(unread > 0 ? ", unread" : ""). \(preview)\(caption.map { ". \($0)" } ?? "")")
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
