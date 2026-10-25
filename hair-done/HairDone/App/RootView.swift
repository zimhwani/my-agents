import SwiftUI
import UIKit

/// Decides which shell you see: onboarding, the client tabs, or Pro mode.
/// Switching sides passes through a full-screen ink frame ("Pro mode." / "Booking mode.").
struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The side the shell last settled on while the tabs were showing. Nil outside the tabs.
    /// While it differs from `app.mode`, the ink frame is up.
    @State private var settledMode: AppMode? = nil
    @State private var switchToken = 0

    var body: some View {
        ZStack {
            if app.isRestoring {
                // A moment on paper while a saved session is picked up, rather than a flash of the welcome video.
                Palette.paper.ignoresSafeArea()
            } else {
                switch app.stage {
                case .welcome, .signedIn:
                    OnboardingFlow()
                        .transition(.opacity)
                case .ready:
                    Group {
                        if app.mode == .pro { ProShell() } else { ClientShell() }
                    }
                    .transition(shellTransition)
                }
            }

            if let curtain = curtainMode {
                ModeCurtain(mode: curtain)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: 0.2)),
                        removal: .opacity.animation(.easeOut(duration: 0.3))
                    ))
                    .zIndex(10)
            }
        }
        .animation(Motion.springSlow, value: app.stage)
        .animation(Motion.springSlow, value: app.mode)
        .overlay(alignment: .bottom) { ToastView() }
        // Back from Stripe with nothing payout-related on screen (the app was closed in between).
        .payoutNoticeAlert(fallback: true)
        // Ink, not lacquer: system controls that aren't styled by hand (back chevrons, DatePicker,
        // ShareLink, links) take this. Lacquer is set by hand on the few things that earn it.
        .tint(Palette.ink)
        .preferredColorScheme(nil)
        .onAppear { settledMode = inShells ? app.mode : nil }
        .onChange(of: inShells) { _, now in settledMode = now ? app.mode : nil }
        .onChange(of: app.mode) { _, new in modeChanged(to: new) }
    }

    // MARK: Switching sides

    private var inShells: Bool { !app.isRestoring && app.stage == .ready }

    /// The side being switched to while the ink frame is up. Derived, so the frame is already there
    /// in the same update that swaps the shells; the new side never flashes before it.
    /// Under Reduce Motion the frame still comes up with its words: it only ever fades.
    private var curtainMode: AppMode? {
        guard inShells, let settled = settledMode, settled != app.mode else { return nil }
        return app.mode
    }

    /// Under the frame the new shell fades in late (a cross-fade, so the same under Reduce Motion).
    /// Arriving from onboarding it rises from the bottom, or fades under Reduce Motion.
    private var shellTransition: AnyTransition {
        if curtainMode != nil {
            return .asymmetric(insertion: .opacity.animation(.easeOut(duration: 0.2).delay(0.2)), removal: .opacity)
        }
        if reduceMotion { return .opacity }
        return .asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity)
    }

    /// `AppState.switchMode` gives the medium haptic; this adds the frame and the announcement.
    private func modeChanged(to new: AppMode) {
        guard inShells, settledMode != nil else {
            settledMode = inShells ? new : nil
            return
        }
        UIAccessibility.post(notification: .screenChanged, argument: new == .pro ? "Pro mode" : "Booking mode")
        switchToken += 1
        let token = switchToken
        // Reduce Motion holds the words a little longer: with nothing moving, the fade is the cue.
        let hold: UInt64 = reduceMotion ? 550_000_000 : 350_000_000
        Task { @MainActor in
            // About 600ms in all: 200 in, a 150 hold on "Pro mode.", then 300 out.
            try? await Task.sleep(nanoseconds: hold)
            guard token == switchToken else { return }
            withAnimation(.easeOut(duration: 0.3)) { settledMode = app.mode }
        }
    }
}

/// The ink frame shown for a moment when she changes sides. It only fades in and out, so it's the
/// same under Reduce Motion.
private struct ModeCurtain: View {
    var mode: AppMode

    var body: some View {
        ZStack(alignment: .leading) {
            Color(hex: 0x241A16).ignoresSafeArea()
            Text(mode == .pro ? "Pro mode." : "Booking mode.")
                .font(HDFont.display)
                .foregroundStyle(Palette.onInk)
                .padding(.horizontal, Space.gutter)
        }
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
}

/// Client side: Home · Bookings · Inbox · You
struct ClientShell: View {
    @Environment(AppState.self) private var app

    var body: some View {
        TabStack(tabs: ClientTab.allCases, selected: app.selectedTab) { tab in
            switch tab {
            case .home: HomeView()
            case .bookings: BookingsView()
            case .inbox: InboxView(side: .client)
            case .you: AccountView()
            }
        }
        .overlay(alignment: .bottom) {
            if showsBar {
                HDTabBar(items: [
                    .init(id: ClientTab.home.rawValue, title: "Home", symbol: "house"),
                    .init(id: ClientTab.bookings.rawValue, title: "Bookings", symbol: "calendar"),
                    .init(id: ClientTab.inbox.rawValue, title: "Inbox", symbol: "bubble.left", unread: app.unreadCount > 0),
                    .init(id: ClientTab.you.rawValue, title: "You", symbol: "person", unread: app.clientYouBadge,
                          dotLabel: "something waiting in Pro mode")
                ], selected: app.selectedTab.rawValue) { id in
                    if let tab = ClientTab(rawValue: id) { app.selectedTab = tab }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .environment(\.tabBarRoom, showsBar ? HDTabBar.height(for: typeSize) : 0)
        .animation(Motion.spring, value: showsBar)
        .trackKeyboard($keyboardUp)
        // Normally already loading (launch, sign-in, a switch); this joins that rather than repeating it.
        .task { if !app.hasLoadedOnce { await app.refreshAll() } }
        // She's done and it's time to pay: Pay comes up by itself, once (AppState.offerPay).
        .sheet(item: Bindable(app).payPrompt) { PaySheet(booking: $0) }
        #if DEBUG
        .modifier(DemoShow())
        #endif
    }

    @State private var keyboardUp = false
    @Environment(\.dynamicTypeSize) private var typeSize
    private var showsBar: Bool { !app.hidesTabBar && !keyboardUp }
}

/// Pro mode: one tab per `ProTab` case, in `allCases` order, on the ink tab bar.
struct ProShell: View {
    @Environment(AppState.self) private var app

    var body: some View {
        TabStack(tabs: ProTab.allCases, selected: app.selectedProTab) { tab in
            root(for: tab)
        }
        .overlay(alignment: .bottom) {
            if showsBar {
                HDTabBar(style: .pro, items: ProTab.allCases.map(item(for:)), selected: app.selectedProTab.rawValue) { id in
                    if let tab = ProTab(rawValue: id) { app.selectedProTab = tab }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .environment(\.tabBarRoom, showsBar ? HDTabBar.height(for: typeSize) : 0)
        .animation(Motion.spring, value: showsBar)
        .trackKeyboard($keyboardUp)
        // Opening straight into Pro mode (remembered from last time) loads here too.
        .task { if !app.hasLoadedOnce { await app.refreshAll() } }
    }

    /// The screen for each pro tab. Exhaustive on purpose: a new `ProTab` case won't build until
    /// it has a screen here and an item below.
    @ViewBuilder
    private func root(for tab: ProTab) -> some View {
        switch tab {
        case .today: ProTodayView()
        case .calendar: ProCalendarView()
        case .inbox: InboxView(side: .pro)
        case .earnings: ProEarningsView()
        // PROFILE TAB
        case .profile: ProProfileTab()
        }
    }

    /// Title and outline glyph for each pro tab.
    private func item(for tab: ProTab) -> HDTabBar.Item {
        switch tab {
        case .today: return .init(id: tab.rawValue, title: "Today", symbol: "sun.horizon", unread: !app.openRequests.isEmpty,
                                  dotLabel: "requests waiting")
        case .calendar: return .init(id: tab.rawValue, title: "Calendar", symbol: "calendar")
        case .inbox: return .init(id: tab.rawValue, title: "Inbox", symbol: "bubble.left", unread: app.unreadCount > 0)
        case .earnings: return .init(id: tab.rawValue, title: "Earnings", symbol: "chart.bar")
        // PROFILE TAB: the dot is something waiting on her booking side (item 7).
        case .profile: return .init(id: tab.rawValue, title: "Profile", symbol: "person.crop.circle", unread: app.otherSideUnreadCount > 0,
                                    dotLabel: "messages waiting in booking mode")
        }
    }

    @State private var keyboardUp = false
    @Environment(\.dynamicTypeSize) private var typeSize
    private var showsBar: Bool { !app.hidesTabBar && !keyboardUp }
}

// MARK: - Tabs

/// The tabs, without a system TabView. The bar is laid over the bottom of the shell, and every screen
/// in a tab's NavigationStack makes room for it itself (`tabBarRoom`, via `hdDestinations()`): on
/// iOS 26 neither a TabView nor a bottom inset on the shell reaches the screens inside the stacks, so
/// the last row of every screen ended up under the bar.
///
/// Like a TabView, a tab is built the first time it's opened and then kept, so switching back
/// finds it where she left it (scroll position, a half-typed message, unsaved hours).
struct TabStack<Tab: Hashable, Content: View>: View {
    var tabs: [Tab]
    var selected: Tab
    @ViewBuilder var content: (Tab) -> Content

    @State private var opened: Set<Tab> = []

    var body: some View {
        ZStack {
            ForEach(tabs, id: \.self) { tab in
                if tab == selected || opened.contains(tab) {
                    let isOn = tab == selected
                    content(tab)
                        .opacity(isOn ? 1 : 0)
                        .allowsHitTesting(isOn)
                        .accessibilityHidden(!isOn)
                        .zIndex(isOn ? 1 : 0)
                }
            }
        }
        .onAppear { opened.insert(selected) }
        .onChange(of: selected) { _, new in opened.insert(new) }
    }
}

extension View {
    /// Keeps `isUp` true while the keyboard is on screen, so the tab bar can step aside for it
    /// the way the system tab bar does.
    func trackKeyboard(_ isUp: Binding<Bool>) -> some View {
        onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isUp.wrappedValue = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isUp.wrappedValue = false
        }
        // Belt and braces: a missed will-hide (a swipe back mid-type) mustn't leave the bar gone.
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
            isUp.wrappedValue = false
        }
    }
}

/// The custom tab bar, thin outline icons with labels, a 4pt lacquer dot under the active tab and
/// a lacquer dot for unread. No system red, no counters, no filled icons.
///
/// - `.client`: paper with a blur and a hairline on top; ink active, inkSoft inactive.
/// - `.pro`: the pro-mode signal on every pro screen. A solid ink bar (#241A16, no blur) with paper
///   icons and labels, 100% active and 55% inactive (5.3:1). In dark mode it inverts to a paper bar
///   with ink icons (65% inactive, 4.9:1) so it never blends into the dark ground.
///
/// Labels scale with Dynamic Type up to xxxLarge; past that, a long press shows the large content viewer.
struct HDTabBar: View {
    enum Style { case client, pro }

    struct Item: Identifiable {
        let id: String
        let title: String
        let symbol: String
        var unread: Bool = false
        /// What VoiceOver says the dot means: "unread messages" on Inbox, "requests waiting" on Today.
        var dotLabel: String = "unread messages"
    }

    /// The bar's height above the home indicator at the default text size: 6 top padding plus 49.
    static let height: CGFloat = 55

    /// The bar's height at a text size.
    static func height(for typeSize: DynamicTypeSize) -> CGFloat {
        6 + rowHeight(labelSize: labelSize(for: typeSize))
    }

    var style: Style = .client
    var items: [Item]
    var selected: String
    var onSelect: (String) -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let labelSize = Self.labelSize(for: typeSize)
        HStack(spacing: 0) {
            ForEach(items) { item in
                let isOn = item.id == selected
                Button {
                    if !isOn { Haptics.selection() }
                    onSelect(item.id)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 21, weight: .light))
                            .frame(height: 26)
                            .overlay(alignment: .topTrailing) {
                                if item.unread {
                                    Circle().fill(dotColor)
                                        .frame(width: 7, height: 7)
                                        .overlay(Circle().strokeBorder(groundColor, lineWidth: 1.5))
                                        .offset(x: 4, y: -1)
                                }
                            }
                        Text(item.title)
                            .font(.system(size: labelSize, weight: isOn ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Circle()
                            .fill(isOn ? dotColor : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                    .foregroundStyle(isOn ? activeColor : inactiveColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.rowHeight(labelSize: labelSize))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.unread ? "\(item.title), \(item.dotLabel)" : item.title)
                .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
                .accessibilityShowsLargeContentViewer {
                    Label(item.title, systemImage: item.symbol)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .background { barGround }
    }

    // MARK: Look

    private var isProInverted: Bool { style == .pro && scheme == .dark }

    @ViewBuilder
    private var barGround: some View {
        switch style {
        case .client:
            Rectangle().fill(.ultraThinMaterial)
                .overlay(Palette.paper.opacity(0.78))
                .overlay(alignment: .top) { Rectangle().fill(Palette.ink.opacity(0.12)).frame(height: 0.5) }
                .ignoresSafeArea(edges: .bottom)
        case .pro:
            Rectangle().fill(groundColor)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    /// Fixed values for the pro bar: it's the opposite of the ground in both modes.
    private static let proInk = Color(hex: 0x241A16)
    private static let proPaper = Color(hex: 0xF4ECE4)

    private var groundColor: Color {
        switch style {
        case .client: return Palette.paper
        case .pro: return isProInverted ? Self.proPaper : Self.proInk
        }
    }

    private var activeColor: Color {
        switch style {
        case .client: return Palette.ink
        case .pro: return isProInverted ? Self.proInk : Self.proPaper
        }
    }

    private var inactiveColor: Color {
        switch style {
        case .client: return Palette.inkSoft
        case .pro: return activeColor.opacity(isProInverted ? 0.65 : 0.55)
        }
    }

    /// On the client bar the dot is the scheme's lacquer; on the pro bar the fixed fill lacquer,
    /// which holds 3:1 against both the ink and the paper ground.
    private var dotColor: Color { style == .pro ? Palette.lacquerFill : Palette.lacquer }

    // MARK: Sizes

    /// The label's point size: 10 at the default size, scaled like caption2, stopping at xxxLarge.
    static func labelSize(for typeSize: DynamicTypeSize) -> CGFloat {
        let clamped = min(typeSize, .xxxLarge)
        let traits = UITraitCollection(preferredContentSizeCategory: contentSizeCategory(for: clamped))
        return UIFontMetrics(forTextStyle: .caption2).scaledValue(for: 10, compatibleWith: traits)
    }

    /// Icon 26 + 3 + label line + 3 + dot 4. 49 at the default size.
    private static func rowHeight(labelSize: CGFloat) -> CGFloat {
        26 + 3 + (labelSize * 1.2).rounded(.up) + 3 + 4 + 1
    }

    private static func contentSizeCategory(for size: DynamicTypeSize) -> UIContentSizeCategory {
        switch size {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        default: return .extraExtraExtraLarge
        }
    }
}

/// Bottom toast for short confirmations, driven by `AppState.show(_:)`. A squared 6pt bar on the
/// ink ground (never `Palette.ink`, which is cream in dark), inset 20 from the edges, SF 15 `onInk`
/// text, left-aligned, with the `inkEdge` hairline so it keeps an edge on dark paper.
struct ToastView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        if let toast = app.toast {
            Text(toast)
                .font(HDFont.sub)
                .foregroundStyle(Palette.onInk)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.l)
                .padding(.vertical, 14)
                .background(Palette.inkGround, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.inkEdge, lineWidth: 0.5))
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, 70)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

#Preview("Pro tab bar") {
    VStack(spacing: 0) {
        Spacer()
        HDTabBar(style: .pro, items: [
            .init(id: "today", title: "Today", symbol: "sun.horizon"),
            .init(id: "calendar", title: "Calendar", symbol: "calendar"),
            .init(id: "inbox", title: "Inbox", symbol: "bubble.left", unread: true),
            .init(id: "earnings", title: "Earnings", symbol: "chart.bar"),
            .init(id: "profile", title: "Profile", symbol: "person")
        ], selected: "today") { _ in }
    }
    .paperBackground()
}
