import SwiftUI

@main
struct HairDoneApp: App {
    /// The real backend when HairDone.xcconfig has its keys, the sample data when it doesn't.
    @State private var app = AppState.configured()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .tint(Palette.lacquer)
                .task { await app.restoreSession() }
                .onOpenURL { url in open(url) }
        }
    }

    /// `hairdone://payouts/done` and `/refresh` come back from Stripe's payout setup;
    /// `hairdone://stripe-redirect` from a bank's card check.
    private func open(_ url: URL) {
        if PaymentRedirect.handle(url) { return }
        guard url.scheme == "hairdone", url.host == "payouts" else { return }
        Task { await app.payoutsReturned() }
    }
}
