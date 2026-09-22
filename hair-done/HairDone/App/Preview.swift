import SwiftUI

/// A ready-to-go AppState for previews: signed in, mock data loaded, no latency.
@MainActor
func previewApp(mode: AppMode = .client, stage: SessionStage = .ready) -> AppState {
    let mock = MockDataService()
    mock.latencyMs = 0
    let app = AppState(data: mock, payments: MockPaymentService(), location: LocationService())
    app.client = MockData.client
    app.proSelf = MockData.proSelf
    app.pros = MockData.pros
    app.bookings = MockData.bookings()
    app.proBookings = MockData.proBookings()
    app.threads = MockData.threads()
    app.payouts = MockData.payouts()
    app.mode = mode
    app.stage = stage
    return app
}
