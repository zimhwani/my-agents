import SwiftUI

/// Ours, before iOS asks: what she'll get and why. "Turn on" brings up the system prompt.
/// Shown once per side, at the moment it explains itself: a client's first booking, a pro's first Today.
struct PushPrePrompt: View {
    @Environment(\.dismiss) private var dismiss
    var side: PushAskSide

    private var title: String { side == .pro ? "New requests and messages" : "Booking updates" }

    private var line: String {
        side == .pro
            ? "So you see requests in time. They lapse after two hours."
            : "So you know when she's confirmed and on her way."
    }

    private var note: String? { side == .pro ? nil : "Nothing else unless you turn it on." }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Space.m) {
                Image(systemName: "bell")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Palette.lacquer)
                    .frame(width: 56, height: 56)
                    .background(Palette.lacquerSoft, in: Circle())
                    .accessibilityHidden(true)
                Text(title)
                    .font(HDFont.title)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(line)
                    .font(HDFont.body)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if let note {
                    Text(note)
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            .padding(.top, Space.xl)

            Spacer(minLength: Space.l)

            VStack(spacing: Space.xs) {
                PrimaryButton(title: "Turn on") {
                    dismiss()
                    Task { await PushCenter.shared.requestPermission() }
                }
                TertiaryButton(title: "Not now") { dismiss() }
            }
            .padding(.bottom, Space.l)
        }
        .screenGutter()
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperBackground()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        // Asked is asked, whichever button she taps or if she swipes it away.
        .onAppear { PushCenter.shared.markAsked(side) }
    }
}

#Preview("Client") {
    Color.clear.sheet(isPresented: .constant(true)) { PushPrePrompt(side: .client) }
}

#Preview("Pro") {
    Color.clear.sheet(isPresented: .constant(true)) { PushPrePrompt(side: .pro) }
}
