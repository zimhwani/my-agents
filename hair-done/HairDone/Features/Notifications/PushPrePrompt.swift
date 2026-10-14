import SwiftUI

/// Ours, before iOS asks: what she'll get and why. "Turn on" brings up the system prompt.
/// Shown once per side, at the moment it explains itself: a client's first booking, a pro's first Today.
/// Paper, a bare outline bell, a serif line, an ink button. No lacquer: nothing here is money.
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
            HStack {
                Spacer()
                IconButton(symbol: "xmark", label: "Close") { dismiss() }
                    .padding(.trailing, -12)
            }
            .padding(.top, Space.s)

            VStack(alignment: .leading, spacing: Space.m) {
                Image(systemName: "bell")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Palette.ink)
                    .accessibilityHidden(true)
                Text(title)
                    .font(HDFont.titleSmall)
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
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: Space.xl)

            VStack(spacing: Space.xs) {
                InkButton(title: "Turn on") {
                    dismiss()
                    Task { await PushCenter.shared.requestPermission() }
                }
                TertiaryButton(title: "Not now") { dismiss() }
            }
            .padding(.bottom, Space.s)
        }
        .screenGutter()
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.paper)
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
