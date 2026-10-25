import SwiftUI
import PhotosUI

// Shared bits for Pro mode: week maths, payout sums, the tab header, the status action button
// (with No show), the decline sheet, the service editor, the hours editor, and the two pieces that
// span screens: unsaved edits (asked about before a mode switch) and the booking-side banner.

// MARK: - Weeks and money

enum ProWeek {
    /// Monday at midnight for whatever week `date` sits in.
    static func monday(of date: Date) -> Date {
        let day = date.startOfDay
        let offset = Weekday.week.firstIndex(of: day.weekday) ?? 0
        return day.adding(days: -offset)
    }

    static func days(from monday: Date) -> [Date] { (0..<7).map { monday.adding(days: $0) } }

    static func contains(_ date: Date, weekOf monday: Date) -> Bool {
        date >= monday && date < monday.adding(days: 7)
    }
}

enum ProMoney {
    /// Bookings that have actually earned her something.
    static func earning(_ bookings: [Booking]) -> [Booking] { bookings.filter { $0.status.isFinished } }

    static func payout(_ bookings: [Booking], from: Date, to: Date) -> Int {
        earning(bookings).filter { $0.start >= from && $0.start < to }.reduce(0) { $0 + $1.price.proPayoutCents }
    }

    static func payout(_ bookings: [Booking], on day: Date) -> Int {
        let start = day.startOfDay
        return payout(bookings, from: start, to: start.adding(days: 1))
    }

    static func payout(_ bookings: [Booking], weekOf monday: Date) -> Int {
        payout(bookings, from: monday, to: monday.adding(days: 7))
    }

    /// What a service price becomes after the 12%.
    static func afterFee(_ cents: Int) -> Int {
        cents - Int((Double(cents) * Fees.platformRate).rounded())
    }

    static func dollars(_ text: String) -> Int {
        let cleaned = text.filter { $0.isNumber || $0 == "." }
        return Int(((Double(cleaned) ?? 0) * 100).rounded())
    }

    static func dollarsText(_ cents: Int) -> String {
        cents % 100 == 0 ? String(cents / 100) : String(format: "%.2f", Double(cents) / 100)
    }

    /// What the client pays for a no-show: everything but a tip.
    static func noShowCharge(_ b: Booking) -> Int {
        b.price.servicesCents + b.price.travelFeeCents + b.price.bookingFeeCents
    }

    /// What she gets for a no-show: her side, after the 12%.
    static func noShowPayout(_ b: Booking) -> Int {
        b.price.servicesCents + b.price.travelFeeCents - b.price.platformFeeCents
    }
}

// MARK: - Words and times

enum ProFlow {
    /// The one button for the job's current state.
    static func nextStep(for status: BookingStatus) -> (title: String, next: BookingStatus)? {
        switch status {
        case .confirmed: return ("On my way", .onHerWay)
        case .onHerWay: return ("I'm here", .arrived)
        case .arrived: return ("Start", .inProgress)
        case .inProgress: return ("Mark done", .done)
        default: return nil
        }
    }

    static let declineReasons = [
        "That time doesn't work for me",
        "Too far for me to travel",
        "I don't do that service",
        "I'm fully booked that day",
        "Something else"
    ]

    /// When a request lapses: two hours after it came in, as the server does it.
    static func deadline(_ b: Booking) -> Date { b.createdAt.adding(hours: Fees.autoDeclineHours) }

    /// "Reply by 11:40 am", or "About to lapse" once it's up.
    static func replyBy(_ b: Booking, now: Date = Date()) -> String {
        let deadline = deadline(b)
        return deadline <= now ? "About to lapse" : "Reply by \(deadline.clock)"
    }

    /// "1 h 12 min to answer", "48 min to answer", "About to lapse". Minutes are "min": "m" is metres.
    static func timeLeft(_ b: Booking, now: Date = Date()) -> String {
        let minutes = Int(deadline(b).timeIntervalSince(now) / 60)
        if minutes <= 0 { return "About to lapse" }
        if minutes < 60 { return "\(minutes) min to answer" }
        return minutes % 60 == 0 ? "\(minutes / 60) h to answer" : "\(minutes / 60) h \(minutes % 60) min to answer"
    }

    /// How much of the two hours is left, 1 to 0: the line under a request that empties as it runs down.
    static func timeLeftFraction(_ b: Booking, now: Date = Date()) -> Double {
        let whole = Double(Fees.autoDeclineHours * 3600)
        return min(max(deadline(b).timeIntervalSince(now) / whole, 0), 1)
    }

    /// `On my way` opens this long before the start (product spec §5).
    static let onMyWayLeadHours = 3

    /// When `On my way` opens for a confirmed job. Before it, the job shows "On my way opens at 9:30 am."
    static func onMyWayOpens(_ b: Booking) -> Date { b.start.adding(hours: -onMyWayLeadHours) }

    /// "today", "tomorrow" or "Tue 24 Sep", for the middle of a sentence.
    static func inSentence(_ date: Date) -> String {
        let friendly = date.friendlyDay
        return friendly == date.shortDay ? friendly : friendly.lowercased()
    }

    /// A stable seed for a client's placeholder. `hashValue` changes every launch; this doesn't.
    static func seed(for id: String) -> Int {
        id.unicodeScalars.reduce(7) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
    }

    static func greetingLead(at date: Date = Date()) -> String {
        switch date.hourOfDay {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default: return "Late one"
        }
    }

    /// "Tuesday 14 October"
    static func longDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_AU")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: date)
    }

    /// "1 job", "3 jobs"
    static func count(_ n: Int, _ one: String, _ many: String) -> String { n == 1 ? "1 \(one)" : "\(n) \(many)" }

    /// A client's name in a sentence, or "your client" while it's still on its way
    /// (`AppState.clientName` is empty until then).
    static func who(_ name: String) -> String { name.isEmpty ? "your client" : name }

    /// The same at the start of a sentence: "Ruby's been told", "Your client's been told".
    static func whoLead(_ name: String) -> String { name.isEmpty ? "Your client" : name }

    // MARK: Notice

    /// The "Notice you need" choices, in minutes.
    static let noticeOptions = [60, 120, 240, 1440]

    static func noticeLabel(_ minutes: Int) -> String {
        switch minutes {
        case 60: return "1 hour"
        case 120: return "2 hours"
        case 240: return "4 hours"
        case 1440: return "A day"
        case 2880: return "Two days"
        default: return minutes.minutesLabel
        }
    }

    // MARK: Hours

    /// Hours a week clients can book her, from her usual week.
    static func weeklyHours(_ hours: [Weekday: [TimeRange]]) -> Int {
        let minutes = hours.values.flatMap { $0 }.reduce(0) { $0 + max(0, $1.endMinutes - $1.startMinutes) }
        return Int((Double(minutes) / 60).rounded())
    }

    static func hoursSummary(_ ranges: [TimeRange]) -> String {
        ranges.isEmpty ? "Off" : ranges.sorted { $0.startMinutes < $1.startMinutes }.map(\.label).joined(separator: ", ")
    }
}

// MARK: - Her photo

extension Pro {
    /// Her pinned photo, else her first. Nil when she hasn't added any.
    var proCoverItem: WorkItem? { work.first(where: { $0.isPinned }) ?? work.first }
}

/// Her face if she's set one, else her cover, else the warm photo ground. Squared at 2pt.
struct ProFacePhoto: View {
    var pro: Pro?

    var body: some View {
        ZStack {
            Palette.photoGround
            if let url = pro?.avatarURL {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Palette.photoGround }
            } else if let cover = pro?.proCoverItem {
                WorkTile(item: cover, cornerRadius: 0)
            }
        }
        .photoShape()
        .accessibilityHidden(true)
    }
}

// MARK: - Tab header

/// The top of every pro tab root: "PRO · KIARA M.", then the serif 40 title, with an optional
/// trailing view on the title's baseline (TextTabs, her photo).
struct ProTabHeader<Trailing: View>: View {
    @Environment(AppState.self) private var app
    var title: Text
    var detail: String? = nil
    private let trailing: Trailing

    init(_ title: String, detail: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = Text(title)
        self.detail = detail
        self.trailing = trailing()
    }

    init(text: Text, detail: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = text
        self.detail = detail
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            ProEyebrow(name: app.proSelf?.displayName ?? "You", detail: detail)
            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                title
                    .font(HDFont.display)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                trailing
            }
        }
    }
}

extension ProTabHeader where Trailing == EmptyView {
    init(_ title: String, detail: String? = nil) {
        self.init(title, detail: detail) { EmptyView() }
    }
}

// MARK: - Small marks

/// A line that needs her attention: a 6pt warn dot, then ink text. Warn is never the text colour.
struct WarnDotLine: View {
    var text: String
    var color: Color = Palette.ink
    var font: Font = HDFont.sub

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Circle().fill(Palette.warn).frame(width: 6, height: 6)
                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 1 }
                .accessibilityHidden(true)
            Text(text).font(font).foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A 1pt ink progress line across the full width, on a `line` track.
struct ProgressLine: View {
    var fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(Palette.line)
                Rectangle().fill(Palette.ink).frame(width: proxy.size.width * CGFloat(min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 1)
        .animation(Motion.spring, value: fraction)
        .accessibilityHidden(true)
    }
}

/// Wraps short options onto as many lines as they need.
struct ProFlowLayout: Layout {
    var spacing: CGFloat = Space.s

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Unsaved edits

/// Screens with edits she hasn't saved (Calendar's hours, Profile edit) register here, so a switch
/// to booking (the Profile row, Inbox's Switch, a notification) asks "Save your changes first?"
/// or waits, instead of throwing them away.
@MainActor
@Observable
final class ProUnsavedWork {
    static let shared = ProUnsavedWork()

    struct Entry {
        var save: () async -> Bool
        var discard: () -> Void
    }

    private(set) var entries: [String: Entry] = [:]
    var hasAny: Bool { !entries.isEmpty }
    /// Called when the last entry goes (saved, discarded or cleared). `AppState` opens a
    /// notification tap that was waiting on it.
    @ObservationIgnored var onCleared: (@MainActor () -> Void)? = nil

    func update(_ id: String, dirty: Bool, save: @escaping () async -> Bool, discard: @escaping () -> Void) {
        if dirty {
            entries[id] = Entry(save: save, discard: discard)
        } else {
            clear(id)
        }
    }

    func clear(_ id: String) {
        guard entries[id] != nil else { return }
        entries[id] = nil
        if entries.isEmpty { onCleared?() }
    }

    /// Saves each in turn. False at the first that doesn't save; the rest stay registered.
    func saveAll() async -> Bool {
        for (id, entry) in entries {
            guard await entry.save() else { return false }
            clear(id)
        }
        return true
    }

    func discardAll() {
        let all = entries
        guard !all.isEmpty else { return }
        entries = [:]
        for entry in all.values { entry.discard() }
        onCleared?()
    }
}

/// "Save your changes first?" with Save and Discard, then `proceed`. Swiping it away stays put.
struct SaveFirstSheet: ViewModifier {
    @Binding var isPresented: Bool
    var message: String? = "You've changed things you haven't saved."
    var proceed: () -> Void

    @State private var working = false
    @State private var failed = false
    @State private var go = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, onDismiss: {
                failed = false
                if go { go = false; proceed() }
            }) {
                ConfirmSheet(
                    title: "Save your changes first?",
                    message: message,
                    confirmTitle: "Save",
                    cancelTitle: "Discard",
                    isWorking: working,
                    onConfirm: {
                        Task { @MainActor in
                            working = true
                            let ok = await ProUnsavedWork.shared.saveAll()
                            working = false
                            if ok { go = true; isPresented = false } else { failed = true }
                        }
                    },
                    onCancel: {
                        ProUnsavedWork.shared.discardAll()
                        go = true
                        isPresented = false
                    }
                ) {
                    if failed { FieldMessage(text: "Didn't save. Your changes are still here. Try again.") }
                }
                .confirmSheetPresentation()
            }
    }
}

extension View {
    /// See `SaveFirstSheet`.
    func saveFirstSheet(isPresented: Binding<Bool>, proceed: @escaping () -> Void) -> some View {
        modifier(SaveFirstSheet(isPresented: isPresented, proceed: proceed))
    }
}

// MARK: - The booking side, from here

/// Watches her booking-side threads while she's in Pro mode and puts up one line when a pro
/// messages her there: "Kiara: ‘French tip or plain?’" with `Open`. Shared, so every pro tab
/// shows the same banner and a message is only announced once.
@MainActor
@Observable
final class ProSideBanner {
    static let shared = ProSideBanner()

    struct Banner: Equatable {
        let threadID: String
        let line: String
    }

    var current: Banner? = nil
    @ObservationIgnored private var seen: Set<String> = []
    @ObservationIgnored private var owner: String? = nil
    @ObservationIgnored private var token = 0

    func observe(_ app: AppState) {
        let me = app.client?.id
        let latest = app.otherSideThreads.compactMap { t -> (MessageThread, Message)? in
            guard let m = t.last else { return nil }
            return (t, m)
        }
        // First look (or someone else signed in): what's already there isn't news.
        if owner != me {
            owner = me
            seen = Set(latest.map { $0.1.id })
            current = nil
            return
        }
        for (thread, message) in latest where !seen.contains(message.id) {
            seen.insert(message.id)
            guard thread.unreadForClient > 0, !message.isSystem, message.senderID != me else { continue }
            let name = app.pro(thread.proID)?.firstName ?? "Your pro"
            let words = message.text.count > 60 ? String(message.text.prefix(57)) + "…" : message.text
            show(Banner(threadID: thread.id, line: "\(name): ‘\(words)’"))
        }
    }

    private func show(_ banner: Banner) {
        withAnimation(Motion.spring) { current = banner }
        token += 1
        let mine = token
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(8))
            guard mine == self.token else { return }
            withAnimation(Motion.gentle) { self.current = nil }
        }
    }

    func dismiss() { withAnimation(Motion.gentle) { current = nil } }
}

private struct ProSideBannerModifier: ViewModifier {
    @Environment(AppState.self) private var app
    @State private var center = ProSideBanner.shared
    @State private var askSave = false
    @State private var waiting: String? = nil

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let banner = center.current {
                    HStack(alignment: .center, spacing: Space.m) {
                        Text(banner.line)
                            .font(HDFont.sub)
                            .foregroundStyle(Palette.onInk)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            Haptics.light()
                            open(banner.threadID)
                        } label: {
                            Text("Open").font(HDFont.subMedium).foregroundStyle(Palette.onInk)
                                .underline()
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Switches to booking and opens the conversation")
                    }
                    .padding(.leading, Space.l)
                    .padding(.trailing, Space.s)
                    .padding(.vertical, Space.xs)
                    .background(Palette.inkGround, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.onInk.opacity(0.1), lineWidth: 0.5))
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, Space.xs)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .onAppear {
                center.observe(app)
                takeProfileRoute()
            }
            .onChange(of: app.otherSideThreads) { _, _ in center.observe(app) }
            // Profile edit asked for from booking mode: bring the Profile tab forward; it pushes the screen.
            .onChange(of: app.pendingRoute) { _, _ in takeProfileRoute() }
            .saveFirstSheet(isPresented: $askSave) {
                if let id = waiting { go(id) }
            }
    }

    private func takeProfileRoute() {
        guard case .proProfileEdit = app.pendingRoute, app.selectedProTab != .profile else { return }
        app.selectedProTab = .profile
    }

    private func open(_ threadID: String) {
        center.dismiss()
        if ProUnsavedWork.shared.hasAny {
            waiting = threadID
            askSave = true
        } else {
            go(threadID)
        }
    }

    private func go(_ threadID: String) {
        waiting = nil
        app.open(PushTarget(kind: .message, bookingID: nil, threadID: threadID, side: .client))
    }
}

extension View {
    /// Put on each pro tab root. See `ProSideBanner`.
    func proSideBanner() -> some View { modifier(ProSideBannerModifier()) }

    /// The same, only when `isOn` (Inbox is shared by both sides; the banner is for Pro mode).
    @ViewBuilder
    func proSideBanner(isOn: Bool) -> some View {
        if isOn { proSideBanner() } else { self }
    }
}

// MARK: - Status action button

/// "On my way" → "I'm here" → "Start" → "Mark done". Marking done asks first. `No show` sits under
/// it once she's messaged and it's 15 minutes past the later of the start time and her "I'm here"
/// (as the server checks it, migration 0012). After done, a static warn dot: "Waiting for Ruby to pay."
/// `clientName` may be empty while it loads; the sentences then say "your client".
struct StatusActionButton: View {
    @Environment(AppState.self) private var app
    var booking: Booking
    var clientName: String
    /// On the ink job hero: paper button, paper text.
    var onInk = false
    /// Drawn as an outline (the quieter one) when something else on screen is the main action.
    var quiet = false
    @State private var busy = false
    @State private var confirmDone = false
    @State private var confirmNoShow = false

    private var soft: Color { onInk ? Palette.onInkSoft : Palette.inkSoft }
    private var strong: Color { onInk ? Palette.onInk : Palette.ink }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            if let step = ProFlow.nextStep(for: booking.status) {
                if booking.status == .confirmed {
                    // On my way opens 3 hours before the start; until then, when it does. Looks again
                    // every 30 seconds, so it opens on time without a refresh.
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        let opens = ProFlow.onMyWayOpens(booking)
                        // "at 9:30 am" on the day; "tomorrow at 7:00 am" from a job further out.
                        let when = Calendar.current.isDateInToday(opens) ? "at \(opens.clock)" : "\(ProFlow.inSentence(opens)) at \(opens.clock)"
                        if context.date < opens {
                            Text("On my way opens \(when).")
                                .font(HDFont.sub).foregroundStyle(soft)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(minHeight: 44, alignment: .leading)
                        } else {
                            live(step)
                        }
                    }
                } else {
                    live(step)
                }
            } else if booking.status == .done {
                WarnDotLine(text: "Waiting for \(who) to pay.", color: strong)
                    .frame(minHeight: 44, alignment: .leading)
            }
        }
        .confirmSheet(isPresented: $confirmDone,
                      title: "Mark it done?",
                      message: "\(whoLead)'s asked to pay \(Money.format(booking.price.clientTotalCents)) now. If they don't, we charge their card in 12 hours. \(Money.format(booking.price.proPayoutCents)) comes to you.",
                      confirmTitle: "Yes, done",
                      cancelTitle: "Not yet") {
            Task { await move(to: .done) }
        }
        .confirmSheet(isPresented: $confirmNoShow,
                      title: "Mark \(who) as a no-show?",
                      message: noShowMessage,
                      confirmTitle: "Mark no-show",
                      cancelTitle: "Wait a bit longer") {
            Task { await move(to: .noShow) }
        }
    }

    private var who: String { ProFlow.who(clientName) }
    private var whoLead: String { ProFlow.whoLead(clientName) }

    /// The button for the step, with the offline line and (once she's there) No show under it.
    private func live(_ step: (title: String, next: BookingStatus)) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            if quiet {
                OutlineButton(title: step.title, isLoading: busy, isEnabled: !app.isOffline, tone: onInk ? .onInk : .paper) { tap(step) }
            } else {
                InkButton(title: step.title, isLoading: busy, isEnabled: !app.isOffline, tone: onInk ? .onInk : .ink) { tap(step) }
            }
            if app.isOffline {
                Text("Updates need a connection. Try again when you're back.")
                    .font(HDFont.caption).foregroundStyle(soft)
            }
            if booking.status == .arrived { noShow }
        }
    }

    private func tap(_ step: (title: String, next: BookingStatus)) {
        if step.next == .done { confirmDone = true } else { Task { await move(to: step.next) } }
    }

    // MARK: No show

    private var arrivedAt: Date? { booking.events.last(where: { $0.status == .arrived })?.at }

    /// No show opens 15 minutes after the later of the start time and her "I'm here".
    private var noShowOpens: Date {
        max(booking.start, arrivedAt ?? booking.start).addingTimeInterval(15 * 60)
    }

    private var messagesSent: Int {
        guard let me = app.proSelf?.id, let thread = app.thread(for: booking) else { return 0 }
        return thread.messages.filter { $0.senderID == me && !$0.isSystem }.count
    }

    private var noShowMessage: String {
        let since = arrivedAt.map { "since \($0.clock)" } ?? "a while"
        let times: String
        switch messagesSent {
        case 0: times = ""
        case 1: times = " and messaged once"
        case 2: times = " and messaged twice"
        default: times = " and messaged \(messagesSent) times"
        }
        return "You've been here \(since)\(times). \(whoLead)'s charged the full \(Money.format(ProMoney.noShowCharge(booking))) and you're paid \(Money.format(ProMoney.noShowPayout(booking))). They can question it for 12 hours."
    }

    private var noShow: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let waited = context.date >= noShowOpens
            if waited && messagesSent > 0 {
                Button {
                    Haptics.light()
                    confirmNoShow = true
                } label: {
                    Text("No show").font(HDFont.subMedium).foregroundStyle(strong)
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(app.isOffline)
            } else {
                Text("No show? Message \(who) first. It opens 15 minutes after the start time, or after you arrived if you were late.")
                    .font(HDFont.caption).foregroundStyle(soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func move(to status: BookingStatus) async {
        busy = true
        defer { busy = false }
        guard let updated = await app.update(booking, to: status) else { return }
        switch status {
        case .onHerWay: app.show("\(whoLead)'s been told you're on your way.")
        case .arrived: app.show("\(whoLead)'s been told you're here.")
        case .inProgress: app.show("Started. Tap Mark done when you're finished.")
        case .done:
            Haptics.success()
            app.show("Done. \(whoLead)'s been asked to pay.")
        case .noShow:
            app.show("Marked as a no-show. \(Money.format(ProMoney.noShowPayout(updated))) comes to you.")
        default: break
        }
    }
}

// MARK: - Decline sheet

struct DeclineSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    var booking: Booking
    var clientName: String
    @State private var picked: Int? = nil
    @State private var other = ""
    @State private var busy = false

    private var isOther: Bool { picked == ProFlow.declineReasons.count - 1 }
    private var canSend: Bool {
        guard let picked else { return false }
        if isOther { return !other.trimmingCharacters(in: .whitespaces).isEmpty }
        return picked >= 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Reason", subtitle: "\(ProFlow.whoLead(clientName)) sees this. Keep it kind.", onClose: { dismiss() })
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(ProFlow.declineReasons.enumerated()), id: \.offset) { i, reason in
                        OptionBox(isSelected: picked == i, style: .row, action: {
                            withAnimation(Motion.spring) { picked = i }
                        }) {
                            Text(reason).font(HDFont.body).foregroundStyle(Palette.ink)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    if isOther {
                        HDTextField(label: "", placeholder: "One line. They'll read it.", text: $other, axis: .vertical)
                            .padding(.top, Space.m)
                            .transition(.opacity)
                    }
                }
                .screenGutter()
                .padding(.top, Space.s)
            }
            VStack(alignment: .leading, spacing: Space.s) {
                InkButton(title: "Decline", isLoading: busy, isEnabled: canSend && !app.isOffline) { Task { await decline() } }
                Text(app.isOffline ? "You're offline. Try again when you're back." : "\(ProFlow.whoLead(clientName))'s hold is released the moment you tap.")
                    .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
            }
            .screenGutter()
            .padding(.vertical, Space.l)
        }
        .paperBackground()
        .holdsPushRoutes()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.paper)
    }

    private func decline() async {
        guard let picked else { return }
        busy = true
        defer { busy = false }
        let reason = isOther ? other.trimmingCharacters(in: .whitespacesAndNewlines) : ProFlow.declineReasons[picked]
        // A failure shows as a toast on this sheet (holdsPushRoutes carries it) and the sheet stays.
        if await app.update(booking, to: .declined, reason: reason) != nil {
            app.show("Declined. \(ProFlow.whoLead(clientName))'s been told and their hold's released.")
            dismiss()
        }
    }
}

// MARK: - A booking as a row

/// One line of a day: time, client, what, status. Used on Today and in Calendar. While the client's
/// name is still loading (`nameKnown` false) a shimmer stands where it goes. Today's rows
/// (`showsPayout`) add the suburb and her payout on the right, and leave Confirmed unsaid.
struct ProBookingRow: View {
    var booking: Booking
    var clientName: String
    var nameKnown = true
    var showDay = false
    var showsHairline = true
    var showsPayout = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Space.m))
        HStack(alignment: .center, spacing: Space.s) {
            layout {
                Text(showDay ? "\(booking.start.friendlyDay) \(booking.start.clock)" : booking.start.clock)
                    .font(HDFont.priceSmall)
                    .foregroundStyle(Palette.ink)
                    .frame(minWidth: showDay ? 0 : 68, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        if nameKnown {
                            Text(clientName).font(HDFont.nameSmall).foregroundStyle(Palette.ink)
                        } else {
                            SkeletonBlock(width: 96, height: 18).padding(.vertical, 2)
                        }
                        if showsPayout {
                            Spacer(minLength: Space.s)
                            Text(Money.format(booking.price.proPayoutCents)).font(HDFont.priceSmall).foregroundStyle(Palette.ink)
                        }
                    }
                    Text(detailLine)
                        .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if !(showsPayout && booking.status == .confirmed) {
                        StatusBadge(status: booking.status, forPro: true).padding(.top, 2)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Palette.inkFaint)
                .accessibilityHidden(true)
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if showsHairline { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the booking")
    }

    /// "BIAB overlay · 1 hr 15 min", or on Today "Gel pedicure · 1 h · Fitzroy North".
    private var detailLine: String {
        showsPayout
            ? "\(booking.servicesLine) · \(booking.minutes.shortDuration) · \(booking.address.suburb)"
            : "\(booking.servicesLine) · \(booking.minutes.minutesLabel)"
    }
}

// MARK: - Suggested services

enum SuggestedServices {
    static func starters(for category: Category) -> [Service] {
        let rows: [(String, Int, Int, String)]
        switch category {
        case .hair: rows = [
            ("Blow-dry", 8000, 45, "Wash and blow-dry, sleek or bouncy."),
            ("Waves or curls", 9000, 50, "On dry hair. Soft or glam."),
            ("Event updo", 13000, 60, "Pinned to last the night.")]
        case .nails: rows = [
            ("Gel manicure", 6500, 60, "Shape, cuticles, gel colour."),
            ("BIAB overlay", 9500, 90, "Builder gel on the natural nail."),
            ("Removal + tidy", 4000, 30, "Soak-off, shape, cuticle oil.")]
        case .makeup: rows = [
            ("Event makeup", 14000, 60, "Full face with lashes."),
            ("Bridal makeup", 22000, 90, "Long-wear, photographed, with a trial option."),
            ("Makeup lesson", 15000, 75, "Your face, your kit, at your mirror.")]
        case .lashes: rows = [
            ("Classic set", 11000, 90, "One lash per lash. Natural."),
            ("Hybrid set", 13000, 100, "Classic and volume mixed."),
            ("Infill", 7500, 60, "Top-up within three weeks.")]
        case .brows: rows = [
            ("Brow lamination", 8500, 45, "Brushed up and set for six weeks."),
            ("Thread + tint", 5500, 30, "Shape and colour."),
            ("Henna brows", 6000, 40, "Stains the skin, lasts two weeks.")]
        case .theLot: rows = [
            ("Hair + makeup", 24000, 100, "Blow-dry or waves, plus a full face."),
            ("Hair + nails", 16000, 120, "Two things, one visit."),
            ("The lot", 32000, 180, "Hair, makeup and nails. Event ready.")]
        }
        return rows.map { Service(id: UUID().uuidString.lowercased(), name: $0.0, category: category, priceCents: $0.1, minutes: $0.2, detail: $0.3) }
    }
}

// MARK: - Service editor

struct ServiceEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    var categories: [Category]
    var onSave: (Service) -> Void
    var onRemove: (() -> Void)? = nil
    private let existingID: String?
    @State private var name: String
    @State private var category: Category
    @State private var priceText: String
    @State private var minutes: Int
    @State private var detail: String
    @State private var isPopular: Bool
    @State private var confirmRemove = false

    init(existing: Service? = nil, categories: [Category], onRemove: (() -> Void)? = nil, onSave: @escaping (Service) -> Void) {
        self.categories = categories.isEmpty ? [.hair] : categories
        self.onSave = onSave
        self.onRemove = onRemove
        existingID = existing?.id
        _name = State(initialValue: existing?.name ?? "")
        _category = State(initialValue: existing?.category ?? categories.first ?? .hair)
        _priceText = State(initialValue: existing.map { ProMoney.dollarsText($0.priceCents) } ?? "")
        _minutes = State(initialValue: existing?.minutes ?? 60)
        _detail = State(initialValue: existing?.detail ?? "")
        _isPopular = State(initialValue: existing?.isPopular ?? false)
    }

    private var priceCents: Int { ProMoney.dollars(priceText) }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && priceCents > 0 }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: existingID == nil ? "Add a service" : "Edit service", onClose: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    HDTextField(label: "Service", placeholder: "Full set, French tip", text: $name)
                    if categories.count > 1 {
                        VStack(alignment: .leading, spacing: Space.s) {
                            Text("Category").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                            ProFlowLayout {
                                ForEach(categories) { c in
                                    OptionBox(title: c.label, isSelected: category == c) { category = c }
                                }
                            }
                        }
                    }
                    HDTextField(label: "Price", placeholder: "95", text: $priceText, keyboard: .decimalPad,
                                caption: priceCents > 0 ? "You get \(Money.format(ProMoney.afterFee(priceCents)))" : "What clients pay for this. Hair Done's 12% comes out of your side.")
                    HDStepper(title: "How long", value: $minutes, in: 15...300, step: 15) { $0.minutesLabel }
                    HDTextField(label: "What's included", placeholder: "Optional", text: $detail, axis: .vertical)
                    HDSwitch(title: "Mark as popular", subtitle: "Shows POPULAR beside it on your profile.", isOn: $isPopular)
                    if onRemove != nil {
                        TertiaryButton(title: "Remove this service") { confirmRemove = true }
                            .padding(.leading, -8)
                    }
                }
                .screenGutter()
                .padding(.vertical, Space.l)
            }
            .scrollDismissesKeyboard(.interactively)
            InkButton(title: "Done", isEnabled: canSave) {
                onSave(Service(id: existingID ?? UUID().uuidString.lowercased(), name: name.trimmingCharacters(in: .whitespaces),
                               category: category, priceCents: priceCents, minutes: minutes, detail: detail, isPopular: isPopular))
                dismiss()
            }
            .screenGutter()
            .padding(.vertical, Space.l)
        }
        .paperBackground()
        .holdsPushRoutes()
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.paper)
        .confirmSheet(isPresented: $confirmRemove,
                      title: "Remove \(removeName)?",
                      message: "It comes off your price list. Bookings you've got for it still stand.",
                      confirmTitle: "Remove it",
                      cancelTitle: "Keep it") {
            onRemove?()
            dismiss()
        }
    }

    private var removeName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "this service" : trimmed
    }
}

/// One service as a price-list row: name and duration on the left, price on the right, `Edit` in ink.
struct ServiceEditRow: View {
    var service: Service
    var onEdit: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            onEdit()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Text(service.name).font(HDFont.body).foregroundStyle(Palette.ink)
                        if service.isPopular { Tag(text: "Popular") }
                    }
                    Text("\(service.durationLabel) · you get \(Money.format(ProMoney.afterFee(service.priceCents)))")
                        .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                }
                Spacer(minLength: Space.s)
                Text(service.priceLabel).font(HDFont.price).foregroundStyle(Palette.ink)
                Text("Edit").font(HDFont.subMedium).foregroundStyle(Palette.ink)
            }
            .padding(.vertical, Space.m)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edits the service")
    }
}

// MARK: - Hours

/// Her usual week as hairline rows (tap a day for its windows), the buffer between jobs, the
/// notice she needs, and a live line: "Clients can book you 32 hours a week."
struct ProHoursForm: View {
    @Binding var hours: [Weekday: [TimeRange]]
    @Binding var bufferMinutes: Int
    @Binding var noticeMinutes: Int
    var showsCopyMonday = false

    private struct EditingDay: Identifiable {
        let day: Weekday
        var id: Int { day.rawValue }
    }
    @State private var editing: EditingDay? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Weekday.week, id: \.self) { day in
                    let ranges = hours[day] ?? []
                    HairlineRow(title: day.long,
                                trailing: Text(ProFlow.hoursSummary(ranges))
                                    .font(HDFont.priceSmall)
                                    .foregroundStyle(ranges.isEmpty ? Palette.inkSoft : Palette.ink)
                                    .multilineTextAlignment(.trailing)) {
                        editing = EditingDay(day: day)
                    }
                    .accessibilityHint("Changes \(day.long)'s hours")
                }
                Text(previewLine)
                    .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    .padding(.top, Space.m)
                if showsCopyMonday {
                    TertiaryButton(title: "Copy Monday to every day", tint: Palette.ink) {
                        let monday = hours[.monday] ?? []
                        withAnimation(Motion.spring) { for d in Weekday.week { hours[d] = monday } }
                    }
                    .padding(.leading, -8)
                }
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                HDStepper(title: "Between jobs", value: $bufferMinutes, in: 0...60, step: 15) { "\($0) min" }
                Text("Time to pack up and drive. Clients can't book inside it.")
                    .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
            }

            VStack(alignment: .leading, spacing: Space.s) {
                Text("Notice you need").font(HDFont.body).foregroundStyle(Palette.ink)
                ProFlowLayout {
                    ForEach(noticeChoices, id: \.self) { m in
                        OptionBox(title: ProFlow.noticeLabel(m), isSelected: noticeMinutes == m) { noticeMinutes = m }
                    }
                }
                Text("Nobody can book you closer to the time than this.")
                    .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
            }
        }
        .sheet(item: $editing) { e in
            DayHoursSheet(day: e.day, windows: hours[e.day] ?? []) { new in
                withAnimation(Motion.spring) { hours[e.day] = new }
            }
        }
    }

    /// The four choices, plus whatever she has now if it isn't one of them.
    private var noticeChoices: [Int] {
        ProFlow.noticeOptions.contains(noticeMinutes) ? ProFlow.noticeOptions : (ProFlow.noticeOptions + [noticeMinutes]).sorted()
    }

    private var previewLine: String {
        let n = ProFlow.weeklyHours(hours)
        return n == 0 ? "Clients can't book you yet. Add some hours." : "Clients can book you \(ProFlow.count(n, "hour", "hours")) a week."
    }
}

/// One day's windows: off or on, each window on two wheels, `Add another window`.
struct DayHoursSheet: View {
    @Environment(\.dismiss) private var dismiss
    var day: Weekday
    var onDone: ([TimeRange]) -> Void
    @State private var windows: [TimeRange]
    /// The wheels' height grows with the text in them.
    @ScaledMetric(relativeTo: .body) private var wheelHeight: CGFloat = 140
    @Environment(\.dynamicTypeSize) private var typeSize

    private let steps = Array(stride(from: 0, through: 24 * 60, by: 15))

    init(day: Weekday, windows: [TimeRange], onDone: @escaping ([TimeRange]) -> Void) {
        self.day = day
        self.onDone = onDone
        _windows = State(initialValue: windows.sorted { $0.startMinutes < $1.startMinutes })
    }

    private var problem: String? {
        if windows.contains(where: { $0.endMinutes <= $0.startMinutes }) { return "A window has to finish after it starts." }
        let sorted = windows.sorted { $0.startMinutes < $1.startMinutes }
        for i in sorted.indices.dropFirst() where sorted[i].startMinutes < sorted[i - 1].endMinutes {
            return "These windows overlap. Move one."
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: day.long, onClose: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    HDSwitch(title: "Working", subtitle: windows.isEmpty ? "Off. Clients can't book you on \(day.long)s." : nil, isOn: Binding(
                        get: { !windows.isEmpty },
                        set: { on in withAnimation(Motion.spring) { windows = on ? [.hours(9, 17)] : [] } }
                    ))
                    ForEach(windows.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: Space.s) {
                            HStack {
                                Text(windows.count > 1 ? "Window \(i + 1)" : "Hours").labelStyle()
                                Spacer()
                                if windows.count > 1 {
                                    TertiaryButton(title: "Remove") { if i < windows.count { _ = withAnimation(Motion.spring) { windows.remove(at: i) } } }
                                }
                            }
                            // Side by side; one over the other at the accessibility sizes, where two won't fit.
                            let wheels = typeSize.isAccessibilitySize
                                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.s))
                                : AnyLayout(HStackLayout(spacing: Space.s))
                            wheels {
                                wheel("Start", binding: Binding(get: { i < windows.count ? windows[i].startMinutes : 0 },
                                                                 set: { if i < windows.count { windows[i].startMinutes = $0 } }))
                                Text("to").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                                wheel("Finish", binding: Binding(get: { i < windows.count ? windows[i].endMinutes : 0 },
                                                                  set: { if i < windows.count { windows[i].endMinutes = $0 } }))
                            }
                        }
                        .padding(.bottom, Space.s)
                        .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
                    }
                    if !windows.isEmpty {
                        TertiaryButton(title: "Add another window", tint: Palette.ink) { addWindow() }
                            .padding(.leading, -8)
                    }
                    if let problem { FieldMessage(text: problem) }
                }
                .screenGutter()
                .padding(.vertical, Space.l)
            }
            InkButton(title: "Done", isEnabled: problem == nil) {
                onDone(windows.sorted { $0.startMinutes < $1.startMinutes })
                dismiss()
            }
            .screenGutter()
            .padding(.vertical, Space.l)
        }
        .paperBackground()
        .holdsPushRoutes()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.paper)
    }

    private func wheel(_ label: String, binding: Binding<Int>) -> some View {
        Picker(label, selection: binding) {
            ForEach(steps, id: \.self) { m in
                Text(TimeRange(startMinutes: m, endMinutes: m).clock(m)).font(HDFont.price).tag(m)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .frame(height: wheelHeight)
        .clipped()
        .accessibilityLabel("\(label) on \(day.long)")
    }

    private func addWindow() {
        let lastEnd = windows.map(\.endMinutes).max() ?? 17 * 60
        let start = min(lastEnd + 60, 22 * 60)
        withAnimation(Motion.spring) { windows.append(TimeRange(startMinutes: start, endMinutes: min(start + 120, 24 * 60))) }
    }
}
