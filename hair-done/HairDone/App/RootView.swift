import SwiftUI

/// Decides which shell you see: onboarding, the client tabs, or Pro mode.
struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ZStack {
            switch app.stage {
            case .welcome, .signedIn:
                OnboardingFlow()
                    .transition(.opacity)
            case .ready:
                Group {
                    if app.mode == .pro { ProShell() } else { ClientShell() }
                }
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            }
        }
        .animation(Motion.springSlow, value: app.stage)
        .animation(Motion.springSlow, value: app.mode)
        .overlay(alignment: .bottom) { ToastView() }
        .preferredColorScheme(nil)
    }
}

/// Client side: Home · Bookings · Inbox · You
struct ClientShell: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(ClientTab.home)
            BookingsView()
                .tabItem { Label("Bookings", systemImage: "calendar") }
                .tag(ClientTab.bookings)
            InboxView()
                .tabItem { Label("Inbox", systemImage: "bubble.left") }
                .tag(ClientTab.inbox)
                .badge(app.unreadCount)
            AccountView()
                .tabItem { Label("You", systemImage: "person") }
                .tag(ClientTab.you)
        }
        .task { if app.pros.isEmpty { await app.refreshAll() } }
    }
}

/// Pro mode: Today · Calendar · Inbox · Work · Earnings
struct ProShell: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.selectedProTab) {
            ProTodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(ProTab.today)
            ProCalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(ProTab.calendar)
            InboxView()
                .tabItem { Label("Inbox", systemImage: "bubble.left") }
                .tag(ProTab.inbox)
                .badge(app.unreadCount)
            ProWorkView()
                .tabItem { Label("Work", systemImage: "photo.on.rectangle.angled") }
                .tag(ProTab.work)
            ProEarningsView()
                .tabItem { Label("Earnings", systemImage: "dollarsign.circle") }
                .tag(ProTab.earnings)
        }
    }
}

/// Bottom toast for short confirmations. Driven by `AppState.show(_:)`.
struct ToastView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        if let toast = app.toast {
            Text(toast)
                .font(HDFont.subStrong)
                .foregroundStyle(Palette.paper)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Palette.ink, in: Capsule())
                .padding(.bottom, 70)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
        }
    }
}
