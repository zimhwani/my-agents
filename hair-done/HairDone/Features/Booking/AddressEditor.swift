import SwiftUI

// STUB — replaced by the feature build. Keep this exact type name and initialiser.
struct AddressEditor: View {
    @Environment(AppState.self) private var app
    var address: Address? = nil
    var onSave: (Address) -> Void
    var body: some View {
        Text("AddressEditor").font(HDFont.heading).paperBackground()
    }
}
