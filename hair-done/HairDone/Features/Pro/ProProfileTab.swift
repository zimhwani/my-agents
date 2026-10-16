import SwiftUI
import UserNotifications
import MessageUI

/// The last pro tab: her, as clients see her; the switch back to booking; everything about how
/// she works; and the account things (notifications, help, log out). At the very bottom, quietly,
/// closing her pro profile.
struct ProProfileTab: View {
    @Environment(AppState.self) private var app
    @State private var showPayouts = false
    @State private var showNotifications = false
    @State private var showHelp = false
    @State private var showNotice = false
    @State private var confirmLogout = false
    @State private var confirmClose = false
    @State private var askSave = false
    @State private var closing = false
    @State private var closeProblem: String? = nil
    @State private var savingActive = false
    /// Debug experiment (`-hdEditInSheet YES`): Profile edit in its own sheet, away from the tabs.
    @State private var editInSheet = false

    private enum Destination: Hashable {
        case edit(ProEditSection?)
        case hours
    }

    private var pro: Pro? { app.proSelf }
    /// Kept in `AppState`, so switching to booking and back lands on the same screen.
    private var path: Binding<NavigationPath> { app.path(for: ProTab.profile) }

    /// Jobs that stop her closing: anything not finished and paid, or cancelled.
    private var liveJobs: [Booking] {
        app.proBookings.filter { $0.status.isUpcoming || $0.status == .done }.sorted { $0.start < $1.start }
    }

    var body: some View {
        NavigationStack(path: path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if app.isOffline { OfflineBar().padding(.horizontal, -Space.gutter) }
                    ProTabHeader("Profile.").padding(.top, Space.s)
                    if let pro {
                        headerCard(pro).padding(.top, Space.xl)
                        switchRow.padding(.top, Space.xl)
                        group("How clients see you") {
                            HairlineRow(title: "Work", value: ProFlow.count(pro.work.count, "photo", "photos")) { path.wrappedValue.append(Route.proWork) }
                            HairlineRow(title: "Services and prices", value: "\(pro.services.count)") { path.wrappedValue.append(Destination.edit(.services)) }
                            HairlineRow(title: "Travel area and fee", value: "\(Int(pro.travelRadiusKm)) km · \(Money.format(pro.travelFeeCents))") {
                                if DebugSwitch.on("hdEditInSheet") { editInSheet = true } else { path.wrappedValue.append(Destination.edit(.travel)) }
                            }
                        }
                        group("How you work") {
                            HairlineRow(title: "Hours", value: hoursValue(pro)) { path.wrappedValue.append(Destination.hours) }
                            HairlineRow(title: "Notice you need", value: ProFlow.noticeLabel(pro.noticeMinutes)) { showNotice = true }
                            HairlineRow(title: "Payouts", value: pro.payoutsConnected ? "On" : "Not set up") { showPayouts = true }
                            takingBookings(pro)
                            if pro.reliabilityScore < 1 {
                                HairlineRow(title: "Reliability", subtitle: "Cancelling on a client drops it.",
                                            value: "\(Int((pro.reliabilityScore * 100).rounded()))% kept", chevron: false)
                            }
                        }
                        group("Account") {
                            HairlineRow(title: "Notifications") { showNotifications = true }
                            HairlineRow(title: "Help") { showHelp = true }
                            HairlineRow(title: "Log out", chevron: false) { confirmLogout = true }
                        }
                        closeBlock.padding(.top, Space.section)
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
                case .edit(let section): ProProfileEditView(focus: section).tabBarRoom()
                case .hours: ProHoursScreen().tabBarRoom()
                }
            }
            .proSideBanner()
        }
        // "Edit" on her own profile, opened in booking mode, lands here.
        .receivesPendingRoutes(path) { route in
            if case .proProfileEdit = route { return true }
            return false
        }
        .sheet(isPresented: $showPayouts) { PayoutDetailsSheet() }
        .sheet(isPresented: $editInSheet) { NavigationStack { ProProfileEditView(focus: .travel) } }
        .sheet(isPresented: $showNotifications) { ProNotificationsSheet() }
        .sheet(isPresented: $showHelp) { ProHelpSheet() }
        .sheet(isPresented: $showNotice) { ProNoticeSheet() }
        .confirmSheet(isPresented: $confirmLogout, title: "Log out?",
                      message: "You'll need your phone or email to get back in.",
                      confirmTitle: "Log out", cancelTitle: "Stay") {
            ProUnsavedWork.shared.discardAll()
            app.signOut()
        }
        .confirmSheet(isPresented: $confirmClose, title: "Close your pro profile?",
                      message: "Clients can't find or book you. Money on its way still lands. Your work and reviews are kept if you come back.",
                      confirmTitle: "Close it", cancelTitle: "Keep it") {
            Task { await close() }
        }
        .saveFirstSheet(isPresented: $askSave) { app.switchMode(.client) }
    }

    // MARK: Her, as clients see her

    private func headerCard(_ pro: Pro) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Button {
                Haptics.light()
                path.wrappedValue.append(Destination.edit(nil))
            } label: {
                HStack(alignment: .top, spacing: Space.l) {
                    ProFacePhoto(pro: pro).frame(width: 72, height: 90)
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(pro.displayName).font(HDFont.name).foregroundStyle(Palette.ink)
                        Text(pro.specialtyLine).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Edit your profile").font(HDFont.subMedium).foregroundStyle(Palette.ink)
                            .padding(.top, Space.xs)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Edits your profile")
            NavigationLink(value: Route.pro(pro)) {
                HStack(spacing: 6) {
                    Text("See it as a client")
                    Image(systemName: "arrow.right").font(.system(size: 13, weight: .regular))
                }
                .font(HDFont.subMedium)
                .foregroundStyle(Palette.ink)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Switch

    private var switchRow: some View {
        Button {
            Haptics.light()
            if ProUnsavedWork.shared.hasAny { askSave = true } else { app.switchMode(.client) }
        } label: {
            HStack(alignment: .center, spacing: Space.m) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Switch to booking").font(HDFont.name).foregroundStyle(Palette.onInk)
                    Text("Book your own hair, nails and the rest.").font(HDFont.sub).foregroundStyle(Palette.onInkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if let waiting = otherSideLine {
                        HStack(spacing: Space.s) {
                            Circle().fill(Palette.lacquer).frame(width: 6, height: 6)
                            Text(waiting).font(HDFont.sub).foregroundStyle(Palette.onInk)
                        }
                        .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .regular)).foregroundStyle(Palette.onInkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .inkBlock(padding: Space.l)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressLift(scale: 0.98))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Switches to booking mode")
    }

    /// "1 message from Kiara", "3 messages waiting".
    private var otherSideLine: String? {
        let unread = app.otherSideUnreadCount
        guard unread > 0 else { return nil }
        let senders = Set(app.otherSideThreads.filter { $0.unreadForClient > 0 }.map(\.proID))
        if senders.count == 1, let id = senders.first, let name = app.pro(id)?.firstName {
            return "\(ProFlow.count(unread, "message", "messages")) from \(name)"
        }
        return "\(ProFlow.count(unread, "message", "messages")) waiting"
    }

    // MARK: Rows

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).labelStyle().accessibilityAddTraits(.isHeader).padding(.bottom, Space.xs)
            content()
        }
        .padding(.top, Space.section)
    }

    private func hoursValue(_ pro: Pro) -> String {
        let n = ProFlow.weeklyHours(pro.availability.hours)
        return n == 0 ? "None yet" : "\(n) hrs a week"
    }

    private func takingBookings(_ pro: Pro) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HDSwitch(title: "Taking bookings",
                     subtitle: pro.isActive ? "You're in searches and can be booked." : "Paused. Clients can't find you. Jobs you've got still stand.",
                     isOn: Binding(get: { pro.isActive }, set: { on in Task { await setActive(on) } }))
                .disabled(savingActive || app.isOffline)
                .padding(.vertical, Space.s)
            if DebugSwitch.on("hdProbe") {
                Text("probe row=\(pro.isActive) app=\(app.proSelf?.isActive ?? false) saving=\(savingActive) offline=\(app.isOffline)")
                    .font(.caption2).accessibilityIdentifier("probe-root")
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
    }

    /// Saves at once. AppState puts the old value back (and says why) if it doesn't go.
    private func setActive(_ on: Bool) async {
        guard var p = app.proSelf, p.isActive != on else { return }
        savingActive = true
        defer { savingActive = false }
        p.isActive = on
        if await app.saveProSelf(p) {
            app.show(on ? "You're taking bookings." : "Paused. Clients can't find you.")
        }
    }

    // MARK: Close

    private var closeBlock: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            TertiaryButton(title: closing ? "Closing" : "Close my pro profile") {
                closeProblem = nil
                if let refusal = refusal { closeProblem = refusal } else { confirmClose = true }
            }
            .padding(.leading, -8)
            .disabled(closing || app.isOffline)
            if let closeProblem { FieldMessage(text: closeProblem) }
        }
    }

    /// "Finish or cancel your 2 jobs first." while she has work on.
    private var refusal: String? {
        switch liveJobs.count {
        case 0: return nil
        case 1:
            let name = app.clientName(liveJobs[0].clientID)
            return name.isEmpty ? "Finish or cancel your job first." : "Finish or cancel your job with \(name) first."
        default: return "Finish or cancel your \(liveJobs.count) jobs first."
        }
    }

    private func close() async {
        closing = true
        defer { closing = false }
        ProUnsavedWork.shared.discardAll()
        // On success AppState takes her back to booking itself.
        if !(await app.closeProProfile()) {
            closeProblem = refusal ?? app.lastError ?? "That didn't go through. Try again."
        }
    }
}

// MARK: - Notice

/// "Notice you need": picked, saved at once.
struct ProNoticeSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var saving: Int? = nil
    @State private var failed = false

    private var current: Int { app.proSelf?.noticeMinutes ?? 90 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Notice you need", subtitle: "Nobody can book you closer to the time than this.", onClose: { dismiss() })
            VStack(spacing: 0) {
                ForEach(choices, id: \.self) { m in
                    OptionBox(isSelected: current == m, style: .row, action: { Task { await pick(m) } }) {
                        HStack {
                            Text(ProFlow.noticeLabel(m)).font(HDFont.body).foregroundStyle(Palette.ink)
                            if saving == m { ProgressView().tint(Palette.ink).padding(.leading, Space.s) }
                        }
                    }
                    .disabled(saving != nil || app.isOffline)
                }
                if failed {
                    FieldMessage(text: "Didn't save. Try again.").padding(.top, Space.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .screenGutter()
            .padding(.bottom, Space.xl)
        }
        .confirmSheetPresentation()
    }

    private var choices: [Int] {
        ProFlow.noticeOptions.contains(current) ? ProFlow.noticeOptions : (ProFlow.noticeOptions + [current]).sorted()
    }

    private func pick(_ minutes: Int) async {
        guard var p = app.proSelf, p.noticeMinutes != minutes else { return }
        saving = minutes
        failed = false
        p.noticeMinutes = minutes
        let ok = await app.saveProSelf(p)
        saving = nil
        if ok {
            Haptics.success()
            app.show("Saved.")
            dismiss()
        } else {
            failed = true
        }
    }
}

// MARK: - Notifications

/// What reaches her on the pro side. Requests and messages can't be turned off: requests lapse in
/// two hours, and clients need to reach her. So this mostly says whether iOS will let them through.
struct ProNotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var system: UNAuthorizationStatus = .authorized

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Notifications", onClose: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    if system == .denied || system == .notDetermined {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            FieldMessage(text: system == .denied
                                         ? "Notifications are off in Settings, so requests won't reach you. They lapse after two hours."
                                         : "Notifications aren't on yet, so requests won't reach you. They lapse after two hours.")
                            TertiaryButton(title: system == .denied ? "Open Settings" : "Turn on", tint: Palette.ink) {
                                Task { @MainActor in await turnOn() }
                            }
                            .padding(.leading, -8)
                        }
                    }
                    VStack(spacing: 0) {
                        HairlineRow(title: "New requests and booking changes", subtitle: "Always on. Requests lapse after two hours.", chevron: false)
                        HairlineRow(title: "Messages from clients", subtitle: "Always on, so clients can reach you.", chevron: false)
                        HairlineRow(title: "Heads-up before each job", subtitle: "45 minutes before. Tap when you're on your way.", chevron: false)
                    }
                    Text("Booking-side notifications are in You, in booking mode.")
                        .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                }
                .screenGutter()
                .padding(.top, Space.s)
                .padding(.bottom, Space.section)
            }
        }
        .paperBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.paper)
        .task { system = await PushCenter.shared.status() }
    }

    @MainActor
    private func turnOn() async {
        if system == .denied {
            if let url = URL(string: UIApplication.openSettingsURLString) { _ = await UIApplication.shared.open(url) }
            return
        }
        PushCenter.shared.markAsked(.pro)
        await PushCenter.shared.requestPermission()
        system = await PushCenter.shared.status()
    }
}

// MARK: - Help

/// Pro answers, and a person if they're not enough.
struct ProHelpSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var open: Set<String> = []

    private let faqs: [(String, String)] = [
        ("When I get paid", "Once a client pays, or 12 hours after you mark it done, the money's yours. Stripe pays it to your bank daily. It lands the next business day."),
        ("What Hair Done takes", "12% of your services and travel fee. Tips are all yours. Clients pay a $3 booking fee on top, which doesn't come out of yours."),
        ("Requests and the two hours", "A request waits two hours for you. After that it lapses, the client's told, and it counts against your reliability. Keep notifications on so you see them in time."),
        ("Cancelling on a client", "She's refunded in full and your reliability drops. Under 70% turns instant book off. If something's come up, message her first."),
        ("A client didn't show", "Tap I'm here when you arrive and message her. No show opens 15 minutes after the start time, or after you arrived if you were late. It charges her in full and pays you. She can question it for 12 hours."),
        ("Pausing or closing", "Taking bookings, in Profile, pauses you straight away. Close my pro profile, at the bottom of Profile, takes you off for good. Your work and reviews are kept if you come back.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Help", subtitle: "A person replies, usually the same day.", onClose: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    VStack(spacing: 0) {
                        ForEach(Array(faqs.enumerated()), id: \.offset) { _, faq in faqRow(faq.0, answer: faq.1) }
                    }
                    OutlineButton(title: "Message us") { messageUs() }
                }
                .screenGutter()
                .padding(.top, Space.s)
                .padding(.bottom, Space.section)
            }
        }
        .paperBackground()
        .overlay(alignment: .bottom) { ToastView() }
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.paper)
    }

    private static let supportEmail = "hello@hairdonenailsdone.app"

    /// Mail if there's an account set up (as on the client side's Help); otherwise the address
    /// goes on the clipboard and says so.
    private func messageUs() {
        let url = URL(string: "mailto:\(Self.supportEmail)?subject=Help%20(pro)")
        if MFMailComposeViewController.canSendMail(), let url {
            openURL(url) { accepted in
                if !accepted { Task { @MainActor in copyAddress() } }
            }
        } else {
            copyAddress()
        }
    }

    private func copyAddress() {
        UIPasteboard.general.string = Self.supportEmail
        Haptics.success()
        app.show("Copied \(Self.supportEmail).")
    }

    private func faqRow(_ title: String, answer: String) -> some View {
        let isOpen = open.contains(title)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.light()
                withAnimation(Motion.spring) {
                    if isOpen { open.remove(title) } else { open.insert(title) }
                }
            } label: {
                HStack {
                    Text(title).font(HDFont.body).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Palette.inkFaint)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOpen ? [.isButton, .isSelected] : .isButton)
            .accessibilityHint(isOpen ? "Hides the answer" : "Shows the answer")
            if isOpen {
                Text(answer)
                    .font(HDFont.quote)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Space.l)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
    }
}

#Preview("Profile tab") {
    ProProfileTab().environment(previewApp(mode: .pro))
}
