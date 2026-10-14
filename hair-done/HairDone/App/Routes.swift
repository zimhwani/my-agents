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

struct RouteDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationDestination(for: Route.self) { route in
            switch route {
            case .pro(let pro): ProProfileView(pro: pro)
            case .booking(let id): BookingDetailView(bookingID: id)
            case .proBooking(let id): ProBookingDetailView(bookingID: id)
            case .thread(let id): ThreadView(threadID: id)
            case .proProfileEdit: ProProfileEditView()
            case .proWork: ProWorkView()
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

    /// For the booking flow, pro onboarding, payout setup and sheets with unsaved input. See `PushRouteHold`.
    func holdsPushRoutes() -> some View { modifier(PushRouteHold()) }

    /// Lets a notification open a screen on this tab. See `AppState.open(_:)`.
    func receivesPendingRoutes(_ path: Binding<NavigationPath>, where accepts: @escaping (Route) -> Bool) -> some View {
        modifier(PendingRouteReceiver(path: path, accepts: accepts))
    }
}
