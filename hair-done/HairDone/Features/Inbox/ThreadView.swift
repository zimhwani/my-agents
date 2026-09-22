import SwiftUI

// STUB — replaced by the feature build. Keep this exact type name and initialiser.
struct ThreadView: View {
    @Environment(AppState.self) private var app
    var threadID: String
    var body: some View {
        Text("ThreadView").font(HDFont.heading).paperBackground()
    }
}
