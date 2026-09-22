import SwiftUI

// STUB — replaced by the feature build. Keep this exact type name and initialiser.
struct ProOnboardingFlow: View {
    @Environment(AppState.self) private var app
    var onFinished: () -> Void
    var body: some View {
        Text("ProOnboardingFlow").font(HDFont.heading).paperBackground()
    }
}
