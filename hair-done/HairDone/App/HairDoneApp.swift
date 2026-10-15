import SwiftUI

@main
struct HairDoneApp: App {
    /// The push token and notification taps come in through here.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    /// The real backend when HairDone.xcconfig has its keys, the sample data when it doesn't.
    @State private var app = AppState.configured()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .tint(Palette.ink)
                .task {
                    PushCenter.shared.attach(app)
                    await app.restoreSession()
                }
                .onOpenURL { url in open(url) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { app.becameActive() }
                }
        }
    }

    /// `hairdone://payouts/done` and `/refresh` come back from Stripe's payout setup;
    /// `hairdone://stripe-redirect` from a bank's card check; `hairdone://pro/<id>` is a shared profile
    /// (and `https://hairdone.app/pro/<id>`, once that domain hands links to the app).
    private func open(_ url: URL) {
        if PaymentRedirect.handle(url) { return }
        if let id = proID(in: url) {
            app.openProLink(id)
            return
        }
        guard url.scheme == "hairdone", url.host == "payouts" else { return }
        let finished = url.path != "/refresh"
        Task { await app.payoutsReturned(finished: finished) }
    }

    /// The pro id in a share link, if it is one.
    private func proID(in url: URL) -> String? {
        let parts = url.pathComponents.filter { $0 != "/" }
        if url.scheme == "hairdone", url.host == "pro" { return parts.first }
        if url.scheme == "https", url.host == "hairdone.app", parts.count >= 2, parts[0] == "pro" { return parts[1] }
        return nil
    }
}
