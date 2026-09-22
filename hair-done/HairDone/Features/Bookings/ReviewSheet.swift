import SwiftUI

// STUB — replaced by the feature build. Keep this exact type name and initialiser.
struct ReviewSheet: View {
    @Environment(AppState.self) private var app
    var booking: Booking
    var body: some View {
        Text("ReviewSheet").font(HDFont.heading).paperBackground()
    }
}
