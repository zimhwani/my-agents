import SwiftUI

// STUB — replaced by the feature build. Keep this exact type name and initialiser.
struct ProProfileView: View {
    @Environment(AppState.self) private var app
    var pro: Pro
    var scrollToReviews: Bool = false
    var body: some View {
        Text("ProProfileView").font(HDFont.heading).paperBackground()
    }
}
