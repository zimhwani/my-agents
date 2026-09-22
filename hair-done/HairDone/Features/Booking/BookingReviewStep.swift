import SwiftUI

// MARK: - Step 5: Check it over

/// Everything she's picked, the price with nothing hidden, how she'll pay, and the policy in plain words.
struct ReviewStep: View {
    @Environment(AppState.self) private var app
    @Binding var draft: BookingDraft
    var error: BookingFlowError? = nil
    var onEdit: (BookingStep) -> Void
    var onPickAnotherTime: () -> Void
    var onTryAgain: () -> Void

    @State private var showAddCard = false

    private var pro: Pro { draft.pro }
    private var price: PriceBreakdown { draft.price }

    private var applePay: PaymentMethod? {
        guard app.payments.supportsApplePay else { return nil }
        return app.client?.paymentMethods.first { $0.kind == .applePay }
            ?? PaymentMethod(id: "pm_applepay", kind: .applePay, brand: "Apple Pay", last4: "", expiry: "", isDefault: false)
    }
    private var cards: [PaymentMethod] { app.client?.paymentMethods.filter { $0.kind == .card } ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                StepTitle(title: "Check it over")

                VStack(alignment: .leading, spacing: Space.l) {
                    HStack(spacing: Space.m) {
                        Avatar(name: pro.firstName, seed: pro.seed, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(pro.displayName).font(HDFont.bodyStrong).foregroundStyle(Palette.ink)
                                if pro.isVerified { VerifiedBadge(compact: true) }
                            }
                            Text(pro.specialtyLine).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    Hairline()

                    if let start = draft.start {
                        SummaryRow(
                            label: "When",
                            value: start.friendlyDayTime,
                            detail: "Ends about \(start.adding(minutes: draft.minutes).clock)",
                            changeTitle: "Change"
                        ) { onEdit(.time) }
                    }
                    if let address = draft.address {
                        SummaryRow(
                            label: "Where",
                            value: address.labelled,
                            detail: address.instructions.isEmpty ? nil : address.instructions,
                            changeTitle: "Change"
                        ) { onEdit(.place) }
                    }
                    if !draft.notes.isEmpty || !draft.inspoSeeds.isEmpty {
                        SummaryRow(
                            label: "Notes",
                            value: draft.notes.isEmpty ? "No notes" : draft.notes,
                            detail: photosLine,
                            changeTitle: "Change"
                        ) { onEdit(.notes) }
                    }
                }
                .card()

                // The money. Every line, nothing folded into anything else.
                VStack(alignment: .leading, spacing: Space.m) {
                    HStack {
                        Text("Services").labelStyle()
                        Spacer()
                        Button(action: { Haptics.light(); onEdit(.services) }) {
                            Text("Change").font(HDFont.subStrong).foregroundStyle(Palette.lacquer)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Change services")
                    }
                    ForEach(draft.services) { service in
                        PriceRow(label: service.name, cents: service.priceCents, note: service.durationLabel)
                    }
                    Hairline().padding(.vertical, Space.xs)
                    if price.travelFeeCents > 0 {
                        PriceRow(label: "Travel fee", cents: price.travelFeeCents, note: "Set by \(pro.firstName). Flat, wherever you are in her area.")
                    } else {
                        FreeRow(label: "Travel fee", note: "\(pro.firstName) doesn't charge one.")
                    }
                    PriceRow(label: "Hair Done fee", cents: price.bookingFeeCents, note: "Covers payments and support. Her prices are all-in apart from this.")
                    Hairline().padding(.vertical, Space.xs)
                    PriceRow(label: "Total", cents: price.clientTotalCents, emphasis: true, note: "Held now, charged when she's done.")
                }
                .card()

                // How she pays.
                VStack(alignment: .leading, spacing: Space.m) {
                    Text("Pay with").labelStyle()
                    VStack(spacing: 0) {
                        if let applePay {
                            PaymentRow(isSelected: isPicked(applePay), action: { pick(applePay) }) {
                                ApplePayPill(height: 30).accessibilityHidden(true)
                                Text("Apple Pay").font(HDFont.body).foregroundStyle(Palette.ink)
                            }
                            if !cards.isEmpty {
                                HStack(spacing: Space.m) {
                                    Hairline()
                                    Text("or a card").font(HDFont.caption).foregroundStyle(Palette.inkSoft).fixedSize()
                                    Hairline()
                                }
                                .padding(.vertical, Space.xs)
                            }
                        }
                        ForEach(cards) { card in
                            PaymentRow(isSelected: isPicked(card), action: { pick(card) }) {
                                Image(systemName: "creditcard")
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(Palette.ink)
                                    .frame(width: 28)
                                    .accessibilityHidden(true)
                                Text("\(card.brand) ending \(card.last4)").font(HDFont.body).foregroundStyle(Palette.ink)
                                if card.isDefault { Tag(text: "Default") }
                            }
                            if card.id != cards.last?.id { Hairline() }
                        }
                        if !cards.isEmpty || applePay != nil { Hairline() }
                        Button(action: { Haptics.light(); showAddCard = true }) {
                            HStack(spacing: Space.s) {
                                Image(systemName: "plus.circle").font(.system(size: 18, weight: .medium))
                                Text("Add a card").font(HDFont.subStrong)
                            }
                            .foregroundStyle(Palette.lacquer)
                            .frame(minHeight: 48)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                    .card(padding: Space.m)

                    Text("We hold \(Money.format(price.clientTotalCents)) on your card now. It's charged when \(pro.firstName) marks you done, or 12 hours after that if she forgets. Cancel in time and the hold just drops off.")
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.inkSoft)
                    Text("Card details go to Stripe, not to us.")
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.inkFaint)
                }

                Text("Cancel with more than 24 hours' notice and it's free. Less than that and she keeps half. She's already turned down other work for you. Not there when she arrives and it's the full amount.")
                    .font(HDFont.sub)
                    .foregroundStyle(Palette.inkSoft)

                if let error {
                    errorCard(error)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .screenGutter()
            .padding(.bottom, Space.xl)
            .animation(Motion.spring, value: error)
        }
        .onAppear {
            if draft.paymentMethod == nil {
                draft.paymentMethod = app.client?.defaultPayment ?? applePay ?? cards.first
            }
        }
        .sheet(isPresented: $showAddCard) {
            AddCardSheet { method in
                pick(method)
            }
        }
    }

    private var photosLine: String? {
        let n = draft.inspoSeeds.count
        if n == 0 { return nil }
        return n == 1 ? "1 photo" : "\(n) photos"
    }

    private func isPicked(_ method: PaymentMethod) -> Bool { draft.paymentMethod?.id == method.id }

    private func pick(_ method: PaymentMethod) {
        withAnimation(Motion.spring) { draft.paymentMethod = method }
    }

    @ViewBuilder
    private func errorCard(_ error: BookingFlowError) -> some View {
        switch error {
        case .declined:
            FlowErrorCard(message: error.message, actionTitle: "Add a card") { showAddCard = true }
        case .slotTaken:
            FlowErrorCard(message: error.message, actionTitle: "Pick another", action: onPickAnotherTime)
        case .other:
            FlowErrorCard(message: error.message, actionTitle: "Try again", action: onTryAgain)
        }
    }
}

/// A $0 line that says "Free" instead of "$0".
struct FreeRow: View {
    var label: String
    var note: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(HDFont.body).foregroundStyle(Palette.ink)
                if let note { Text(note).font(HDFont.caption).foregroundStyle(Palette.inkSoft) }
            }
            Spacer()
            Text("Free").font(HDFont.price).foregroundStyle(Palette.success)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One way to pay, with a radio on the right.
struct PaymentRow<Content: View>: View {
    var isSelected: Bool
    var action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: { Haptics.light(); action() }) {
            HStack(spacing: Space.m) {
                content()
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(isSelected ? Palette.lacquer : Palette.inkFaint)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Step 6: You're booked

struct BookedStep: View {
    var booking: Booking
    var pro: Pro
    var onMessage: () -> Void
    var onDone: () -> Void

    private var isRequest: Bool { booking.status == .requested }

    private var title: String { isRequest ? "Requested." : "You're booked." }

    private var sub: String {
        if isRequest {
            return "\(pro.firstName) usually replies within \(pro.replyWindow). We'll ping you. Nothing's charged until she says yes."
        }
        if booking.isToday { return "Sit tight, she's on her way at \(booking.start.clock)." }
        return "\(pro.firstName), \(booking.start.friendlyDayInSentence) at \(booking.start.clock). We'll remind you the day before."
    }

    private var shareText: String {
        "I've got \(pro.firstName) coming \(booking.start.friendlyDayInSentence) at \(booking.start.clock), \(booking.address.short). Booked on Hair Done. Ref \(booking.reference)."
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.section) {
                VStack(spacing: Space.l) {
                    LacquerCheck(size: 112)
                        .padding(.top, Space.xl)
                    VStack(spacing: Space.s) {
                        Text(title)
                            .font(HDFont.hero)
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.center)
                        Text(sub)
                            .font(HDFont.body)
                            .foregroundStyle(Palette.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    .accessibilityElement(children: .combine)
                }

                BookingSummaryCard(booking: booking, pro: pro)

                VStack(spacing: Space.m) {
                    VStack(spacing: Space.xs) {
                        ShareLink(item: shareText) {
                            SecondaryLabel(title: "Share with a friend", symbol: "square.and.arrow.up")
                        }
                        .buttonStyle(PressLift())
                        Text("So someone knows who's coming and when.")
                            .font(HDFont.caption)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    SecondaryButton(title: "Message \(pro.firstName)", symbol: "bubble.left", action: onMessage)
                    PrimaryButton(title: "Done", action: onDone)
                        .padding(.top, Space.xs)
                }
            }
            .screenGutter()
            .padding(.bottom, Space.section)
        }
    }
}

/// Who, when, where, what, and the reference. Used on the booked screen.
struct BookingSummaryCard: View {
    var booking: Booking
    var pro: Pro

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.m) {
                Avatar(name: pro.firstName, seed: pro.seed, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pro.displayName).font(HDFont.bodyStrong).foregroundStyle(Palette.ink)
                    Text(pro.specialtyLine).font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                StatusBadge(status: booking.status)
            }
            Hairline()
            SummaryRow(label: "When", value: booking.start.friendlyDayTime, detail: "Ends about \(booking.end.clock)")
            SummaryRow(label: "Where", value: booking.address.labelled)
            SummaryRow(label: "What", value: booking.servicesLine, detail: booking.minutes.minutesLabel)
            SummaryRow(label: "Total", value: Money.format(booking.price.clientTotalCents), detail: "Held, not charged yet")
            Hairline()
            HStack {
                Text("Reference").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                Spacer()
                Text(booking.reference).font(HDFont.subStrong.monospacedDigit()).foregroundStyle(Palette.ink)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

#Preview("Booked") {
    let app = previewApp()
    return Group {
        if let booking = app.upcomingBookings.first, let pro = app.pro(booking.proID) {
            BookedStep(booking: booking, pro: pro, onMessage: {}, onDone: {})
                .paperBackground()
        }
    }
    .environment(app)
}
