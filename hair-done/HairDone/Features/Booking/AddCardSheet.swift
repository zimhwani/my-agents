import SwiftUI

// STUB — replaced by the feature build. Keep this exact type name and initialiser.
struct AddCardSheet: View {
    @Environment(AppState.self) private var app
    var onAdded: (PaymentMethod) -> Void
    var body: some View {
        Text("AddCardSheet").font(HDFont.heading).paperBackground()
    }
}
