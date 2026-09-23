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
            HomeView().toolbar(.hidden, for: .tabBar).tag(ClientTab.home)
            BookingsView().toolbar(.hidden, for: .tabBar).tag(ClientTab.bookings)
            InboxView().toolbar(.hidden, for: .tabBar).tag(ClientTab.inbox)
            AccountView().toolbar(.hidden, for: .tabBar).tag(ClientTab.you)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !app.hidesTabBar {
                HDTabBar(items: [
                    .init(id: ClientTab.home.rawValue, title: "Home", symbol: "house"),
                    .init(id: ClientTab.bookings.rawValue, title: "Bookings", symbol: "calendar"),
                    .init(id: ClientTab.inbox.rawValue, title: "Inbox", symbol: "bubble.left", unread: app.unreadCount > 0),
                    .init(id: ClientTab.you.rawValue, title: "You", symbol: "person")
                ], selected: app.selectedTab.rawValue) { id in
                    if let tab = ClientTab(rawValue: id) { app.selectedTab = tab }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.spring, value: app.hidesTabBar)
        .task { if app.pros.isEmpty { await app.refreshAll() } }
    }
}

/// Pro mode: Today · Calendar · Inbox · Work · Earnings
struct ProShell: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.selectedProTab) {
            ProTodayView().toolbar(.hidden, for: .tabBar).tag(ProTab.today)
            ProCalendarView().toolbar(.hidden, for: .tabBar).tag(ProTab.calendar)
            InboxView().toolbar(.hidden, for: .tabBar).tag(ProTab.inbox)
            ProWorkView().toolbar(.hidden, for: .tabBar).tag(ProTab.work)
            ProEarningsView().toolbar(.hidden, for: .tabBar).tag(ProTab.earnings)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HDTabBar(items: [
                .init(id: ProTab.today.rawValue, title: "Today", symbol: "sun.max"),
                .init(id: ProTab.calendar.rawValue, title: "Calendar", symbol: "calendar"),
                .init(id: ProTab.inbox.rawValue, title: "Inbox", symbol: "bubble.left", unread: app.unreadCount > 0),
                .init(id: ProTab.work.rawValue, title: "Work", symbol: "photo.on.rectangle"),
                .init(id: ProTab.earnings.rawValue, title: "Earnings", symbol: "dollarsign.circle")
            ], selected: app.selectedProTab.rawValue) { id in
                if let tab = ProTab(rawValue: id) { app.selectedProTab = tab }
            }
        }
    }
}

/// The custom tab bar: paper with a blur, a hairline on top, thin outline icons,
/// ink for the selected tab with a lacquer dot beneath, and a lacquer dot for unread.
/// No system red, no counters, no filled icons.
struct HDTabBar: View {
    struct Item: Identifiable {
        let id: String
        let title: String
        let symbol: String
        var unread: Bool = false
    }

    var items: [Item]
    var selected: String
    var onSelect: (String) -> Void

    var body: some View {
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
                                    Circle().fill(Palette.lacquer)
                                        .frame(width: 7, height: 7)
                                        .overlay(Circle().strokeBorder(Palette.paper, lineWidth: 1.5))
                                        .offset(x: 4, y: -1)
                                }
                            }
                        Text(item.title)
                            .font(.system(size: 10, weight: isOn ? .semibold : .medium))
                        Circle()
                            .fill(isOn ? Palette.lacquer : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                    .foregroundStyle(isOn ? Palette.ink : Palette.inkSoft)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 49)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.unread ? "\(item.title), unread messages" : item.title)
                .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .background {
            Rectangle().fill(.ultraThinMaterial)
                .overlay(Palette.paper.opacity(0.78))
                .overlay(alignment: .top) { Rectangle().fill(Palette.ink.opacity(0.12)).frame(height: 0.5) }
                .ignoresSafeArea(edges: .bottom)
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
