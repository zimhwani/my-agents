import SwiftUI

// STUB — replaced by the feature build. Keep this exact type name and initialiser.
struct BookingFlowView: View {
    @Environment(AppState.self) private var app
    var pro: Pro
    var preselected: [Service] = []
    var onBooked: ((Booking) -> Void)? = nil
    var body: some View {
        Text("BookingFlowView").font(HDFont.heading).paperBackground()
    }
}
