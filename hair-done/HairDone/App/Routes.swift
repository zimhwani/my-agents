import SwiftUI

/// Every push destination in the app. Each tab's NavigationStack calls `.hdDestinations()` once,
/// then any view can `NavigationLink(value: Route.pro(pro))`.
enum Route: Hashable {
    case pro(Pro)
    case booking(String)       // client-side booking detail, by id
    case proBooking(String)    // pro-side booking detail, by id
    case thread(String)        // message thread, by id
    case proProfileEdit
    case proWork               // her Work grid, pushed from the Profile tab

    var isBooking: Bool {
        if case .booking = self { return true }
        return false
    }

    var isProBooking: Bool {
        if case .proBooking = self { return true }
        return false
    }

    var isThread: Bool {
        if case .thread = self { return true }
        return false
    }

    /// A pro's profile: what a shared link opens, on Home.
    var isPro: Bool {
        if case .pro = self { return true }
        return false
    }
}

/// Also makes room for the tab bar under the tab's root and every screen pushed onto it (`tabBarRoom`),
/// and puts paper behind the status bar on the root, which has no header of its own.
struct RouteDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tabBarRoom()
            .modifier(StatusBarPaper())
            .navigationDestination(for: Route.self) { route in
                Group {
                    switch route {
                    case .pro(let pro): ProProfileView(pro: pro)
                    case .booking(let id): BookingDetailView(bookingID: id)
                    case .proBooking(let id): ProBookingDetailView(bookingID: id)
                    case .thread(let id): ThreadView(threadID: id)
                    case .proProfileEdit: ProProfileEditView()
                    case .proWork: ProWorkView()
                    }
                }
                .tabBarRoom()
            }
    }
}

// MARK: - Room for the tab bar

/// How much of the bottom the tab bar covers, above the home indicator: the bar's height while it's
/// showing, 0 while it steps aside (a thread, the keyboard). Set by the tab shells in RootView.
private struct TabBarRoomKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var tabBarRoom: CGFloat {
        get { self[TabBarRoomKey.self] }
        set { self[TabBarRoomKey.self] = newValue }
    }
}

/// Keeps a screen's content, and any bar of its own (Save, Book, the message field), clear of the tab
/// bar. On iOS 26 a bottom inset on the shell doesn't reach the screens inside a tab's NavigationStack,
/// so the last row scrolled under the bar; each screen in the stack makes the room itself instead.
/// Put it outside the screen's own bottom bar so that bar sits on top of the tab bar.
private struct TabBarRoom: ViewModifier {
    @Environment(\.tabBarRoom) private var room

    @ViewBuilder
    func body(content: Content) -> some View {
        if DebugSwitch.on("hdNoRoom") {
            content
        } else {
            content.safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: room).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
}

/// With the system bar hidden, a scrolled tab root ran its text into the clock. A zero-height inset
/// sits just under the status bar; its paper reaches up behind it. (An overlay doesn't work: a
/// ScrollView's frame already runs under the status bar.)
private struct StatusBarPaper: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if DebugSwitch.on("hdNoScrim") {
            content
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 0)
                    .background(Palette.paper.ignoresSafeArea(edges: .top))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// Takes a screen a notification asked for (`AppState.pendingRoute`) when it belongs on this tab,
/// and shows it on top of the tab's root.
struct PendingRouteReceiver: ViewModifier {
    @Environment(AppState.self) private var app
    @Binding var path: NavigationPath
    var accepts: (Route) -> Bool

    func body(content: Content) -> some View {
        content
            .onAppear { take() }
            .onChange(of: app.pendingRoute) { _, _ in take() }
    }

    private func take() {
        guard let route = app.pendingRoute, accepts(route) else { return }
        app.pendingRoute = nil
        var fresh = NavigationPath()
        fresh.append(route)
        path = fresh
    }
}

/// Marks a screen she's in the middle of. While one is up, a tapped notification waits (with a
/// toast here, since the root's toast sits under sheets) and opens when the last one closes.
struct PushRouteHold: ViewModifier {
    @Environment(AppState.self) private var app

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) { ToastView() }
            .onAppear { app.busySurfaces += 1 }
            .onDisappear { app.surfaceClosed() }
    }
}

extension View {
    func hdDestinations() -> some View { modifier(RouteDestinations()) }

    /// See `TabBarRoom`. `hdDestinations()` already does this for a tab's root and its routes.
    func tabBarRoom() -> some View { modifier(TabBarRoom()) }

    /// For the booking flow, pro onboarding, payout setup and sheets with unsaved input. See `PushRouteHold`.
    func holdsPushRoutes() -> some View { modifier(PushRouteHold()) }

    /// Lets a notification open a screen on this tab. See `AppState.open(_:)`.
    func receivesPendingRoutes(_ path: Binding<NavigationPath>, where accepts: @escaping (Route) -> Bool) -> some View {
        modifier(PendingRouteReceiver(path: path, accepts: accepts))
    }
}
