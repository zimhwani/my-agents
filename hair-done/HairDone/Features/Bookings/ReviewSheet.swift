import SwiftUI

/// "How'd Kiara go?" for a paid booking: her photo, the stars, a line if you want. Then thanks.
/// Paying (and the tip) lives in `PaySheet`; this one never takes money.
struct ReviewSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var booking: Booking

    @State private var rating = 0
    @State private var text = ""
    @State private var sending = false
    @State private var sent = false
    /// Why the last go didn't work, shown above the button. A toast would sit under this sheet.
    @State private var problem: String? = nil

    private var pro: Pro? { app.pro(booking.proID) }
    private var proName: String { pro?.firstName ?? "your pro" }

    /// Copy deck `rate.stars.{n}`.
    private var reaction: String {
        switch rating {
        case 1: return "Not good."
        case 2: return "Not great."
        case 3: return "Fine."
        case 4: return "Good."
        case 5: return "Very good."
        default: return " "
        }
    }

    private var placeholder: String {
        rating > 0 && rating < 3 ? "What went wrong? We read these too." : "What were they like? The next person deciding will read this."
    }

    private var thanksLine: String {
        if rating <= 2 { return "Thanks for telling us. A person will look at this." }
        return "Thanks. \(proName) will see it, and so will the next woman deciding."
    }

    var body: some View {
        ZStack {
            if sent { thanks.transition(.opacity) } else { form.transition(.opacity) }
        }
        .paperBackground()
        .animation(reduceMotion ? nil : Motion.springSlow, value: sent)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.paper)
        .holdsPushRoutes()
    }

    // MARK: Form

    private var form: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "How'd \(proName) go?", subtitle: "\(booking.servicesLine) · \(booking.start.friendlyDay)", onClose: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    BookingPhoto(item: booking.coverItem(pro: pro))
                        .frame(width: 120, height: 150)
                        .padding(.top, Space.s)

                    VStack(alignment: .leading, spacing: Space.m) {
                        StarPicker(rating: $rating, size: 40)
                        Text(reaction)
                            .font(HDFont.serifItalic)
                            .foregroundStyle(Palette.ink)
                            .frame(minHeight: 26, alignment: .leading)
                            .accessibilityLabel(rating == 0 ? "Pick a star rating" : "\(rating) stars. \(reaction)")
                    }

                    if rating > 0 {
                        HDTextField(label: "A line, if you want", placeholder: placeholder, text: $text, axis: .vertical, caption: "Optional")
                            .transition(.opacity)
                    }
                }
                .screenGutter()
                .padding(.bottom, Space.section)
            }
            .scrollDismissesKeyboard(.interactively)
            .animation(reduceMotion ? nil : Motion.spring, value: rating > 0)

            VStack(spacing: Space.xs) {
                if let problem {
                    FieldMessage(text: problem)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, Space.xs)
                        .transition(.opacity)
                }
                if app.isOffline { FieldMessage(text: "You're offline. Try again when you're back.").frame(maxWidth: .infinity, alignment: .leading) }
                InkButton(title: "Send", isLoading: sending, isEnabled: rating > 0 && !app.isOffline) { send() }
                TertiaryButton(title: "Not now") { dismiss() }
            }
            .screenGutter()
            .padding(.top, Space.s)
            .padding(.bottom, Space.s)
            .background(Palette.paper)
        }
    }

    // MARK: Thanks

    private var thanks: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Spacer()
            LacquerCheck(size: 56)
            Text(thanksLine)
                .font(HDFont.titleSmall)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .screenGutter()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Closes")
        .task {
            try? await Task.sleep(for: .seconds(1.6))
            dismiss()
        }
    }

    // MARK: Send

    private func send() {
        guard rating > 0, !sending else { return }
        sending = true
        withAnimation(Motion.gentle) { problem = nil }
        Task { @MainActor in
            let outcome = await app.review(booking, rating: rating, text: text.trimmingCharacters(in: .whitespacesAndNewlines), tipCents: 0)
            sending = false
            switch outcome {
            case .saved:
                sent = true
            case .paidOnly:
                dismiss()
            case .failed(let line):
                Haptics.warning()
                withAnimation(Motion.gentle) { problem = line }
            }
        }
    }
}

#Preview("Review") {
    ReviewSheet(booking: MockData.bookings()[4]).environment(previewApp())
}
