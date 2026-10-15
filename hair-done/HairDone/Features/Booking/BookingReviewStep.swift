import SwiftUI

// "Check it over" and "You're booked." sit on ink in light and dark alike: `Palette.inkGround`,
// `inkRaised`, `onInk`, `onInkSoft` and `inkLine`. Lacquer is only on Pay and the drawn check.

// MARK: - The ticket's tear

/// The tear across a ticket: a dashed line with a round notch cut from each edge.
/// The notches are circles in the ground colour, half outside the card; the card's clip trims them.
struct TicketTear: View {
    var notchColor: Color
    var lineColor: Color
    var notch: CGFloat = 18
    var inset: CGFloat = 18

    var body: some View {
        ZStack {
            TicketDashLine()
                .stroke(lineColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .frame(height: 2)
                .padding(.horizontal, inset)
            HStack(spacing: 0) {
                Circle()
                    .fill(notchColor)
                    .frame(width: notch, height: notch)
                    .offset(x: -notch / 2)
                Spacer(minLength: 0)
                Circle()
                    .fill(notchColor)
                    .frame(width: notch, height: notch)
                    .offset(x: notch / 2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: notch)
        .accessibilityHidden(true)
    }
}

/// A straight line through the middle of its frame, for stroking dashed.
struct TicketDashLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// MARK: - Step 5: Check it over

/// The ticket: her work, who's coming and when, every line of the price, and the policy in plain words.
/// Ink, like a ticket. Pay in lacquer and Apple Pay side by side at the bottom (stacked at large text).
struct ReviewStep: View {
    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var draft: BookingDraft
    var error: BookingFlowError? = nil
    var onEdit: (BookingStep) -> Void
    var onPickAnotherTime: () -> Void
    var onTryAgain: () -> Void
    var onSeeWhosFree: () -> Void = {}
    var isPaying: Bool = false
    var onPay: () -> Void = {}

    @State private var showAddCard = false
    @State private var showPicker = false
    @State private var tappedApplePay = false

    private static let errorID = "review-pay-error"

    private var pro: Pro { draft.pro }
    private var price: PriceBreakdown { draft.price }

    private var applePay: PaymentMethod? { ReviewStep.applePayMethod(in: app) }
    private var cards: [PaymentMethod] { ReviewStep.cardMethods(in: app) }

    fileprivate static func applePayMethod(in app: AppState) -> PaymentMethod? {
        guard app.payments.supportsApplePay else { return nil }
        return app.client?.paymentMethods.first { $0.kind == .applePay }
            ?? PaymentMethod(id: "pm_applepay", kind: .applePay, brand: "Apple Pay", last4: "", expiry: "", isDefault: false)
    }

    fileprivate static func cardMethods(in app: AppState) -> [PaymentMethod] {
        app.client?.paymentMethods.filter { $0.kind == .card } ?? []
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    ticket

                    Text(ReviewStep.policy)
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.onInkSoft)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                        .padding(.top, Space.xs)

                    if let error {
                        errorCard(error)
                            .id(ReviewStep.errorID)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, Space.s)
                .padding(.bottom, Space.xl)
                .animation(Motion.spring, value: error)
            }
            .scrollIndicators(.hidden)
            .onChange(of: error) { _, new in
                guard new != nil else { return }
                withAnimation(Motion.spring) { proxy.scrollTo(ReviewStep.errorID, anchor: .bottom) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { payBar }
        .onAppear {
            if draft.paymentMethod == nil {
                // With Stripe's sheet there may be nothing saved yet: the card goes in at checkout.
                draft.paymentMethod = app.client?.defaultPayment ?? applePay ?? cards.first ?? app.payments.checkoutCard
            }
        }
        .sheet(isPresented: $showAddCard) {
            AddCardSheet { method in
                pick(method)
            }
        }
        .sheet(isPresented: $showPicker) {
            PaymentPickerSheet(selected: $draft.paymentMethod, holdLine: holdLine)
        }
    }

    // MARK: The ticket

    private var ticket: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomePhoto(item: pro.homeCover, cornerRadius: 0)
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .clipped()
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Space.s) {
                Text(verbatim: "\(pro.firstName) at yours.")
                    .font(HDFont.title)
                    .foregroundStyle(Palette.onInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: 0) {
                    if let start = draft.start {
                        detailRow("\(start.friendlyDayTime) · \(ShortDuration.label(draft.minutes))", changeLabel: "Change time") {
                            onEdit(.time)
                        }
                    }
                    if let address = draft.address {
                        detailRow(address.labelled, changeLabel: "Change address") {
                            onEdit(.place)
                        }
                    }
                    if let notesLine {
                        detailRow(notesLine, changeLabel: "Change notes and photos") {
                            onEdit(.notes)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 8)

            TicketTear(notchColor: Palette.inkGround, lineColor: Palette.onInk.opacity(0.22))

            // The money. Every line, nothing folded into anything else.
            VStack(alignment: .leading, spacing: 14) {
                ForEach(draft.services) { service in
                    lineItem(service.name, amount: Money.format(service.priceCents))
                }
                if price.travelFeeCents > 0 {
                    lineItem("Travel fee", amount: Money.format(price.travelFeeCents), note: "Set by \(pro.firstName). Flat, wherever you are in her area.")
                } else {
                    lineItem("Travel fee", amount: "Free", note: "\(pro.firstName) doesn't charge one.")
                }
                lineItem("Booking fee", amount: Money.format(price.bookingFeeCents))

                Rectangle()
                    .fill(Palette.inkLine)
                    .frame(height: 1)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                            totalLabel
                            Spacer(minLength: 0)
                            totalAmount
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            totalLabel
                            totalAmount
                        }
                    }
                    Text(isPaying ? "Sorting it." : "Held now, charged when she's done.")
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.onInkSoft)
                }
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(Palette.inkRaised)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Palette.onInk.opacity(0.10), lineWidth: 0.5)
        )
    }

    private var totalLabel: some View {
        Text("Total")
            .font(HDFont.body)
            .foregroundStyle(Palette.onInk)
    }

    private var totalAmount: some View {
        Text(Money.format(price.clientTotalCents))
            .font(HDFont.priceDisplay)
            .tracking(-0.6)
            .foregroundStyle(Palette.onInk)
            .fixedSize()
    }

    private func detailRow(_ text: String, changeLabel: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            Text(verbatim: text)
                .font(HDFont.sub)
                .foregroundStyle(Palette.onInk.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: { Haptics.light(); action() }) {
                Text("Change")
                    .font(HDFont.sub)
                    .foregroundStyle(Palette.onInkSoft)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isPaying)
            .accessibilityLabel(changeLabel)
        }
    }

    private func lineItem(_ label: String, amount: String, note: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                Text(verbatim: label)
                    .font(HDFont.body)
                    .foregroundStyle(Palette.onInk)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text(verbatim: amount)
                    .font(HDFont.price)
                    .foregroundStyle(Palette.onInk)
                    .fixedSize()
            }
            if let note {
                Text(verbatim: note)
                    .font(HDFont.caption)
                    .foregroundStyle(Palette.onInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Paying

    private var payTitle: String {
        let total = Money.format(price.clientTotalCents)
        return pro.instantBook ? "Pay \(total)" : "Request · \(total)"
    }

    private var canPay: Bool { draft.paymentMethod != nil && !app.isOffline }

    private var payingWithLabel: String {
        guard let method = draft.paymentMethod else { return "Add a way to pay" }
        return "Paying with \(method.label). Change"
    }

    private var applePayLabel: String { pro.instantBook ? "Pay with Apple Pay" : "Request with Apple Pay" }

    private var payBar: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            payingWithRow
            if typeSize.isAccessibilitySize {
                VStack(spacing: Space.m) {
                    payButton
                    if applePay != nil { applePayButton }
                }
            } else {
                HStack(spacing: 13) {
                    payButton
                    if applePay != nil { applePayButton }
                }
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.s)
        .padding(.bottom, Space.s)
        .background(Palette.inkGround.ignoresSafeArea(.container, edges: .bottom))
    }

    /// "Paying with Apple Pay · Change". Opens the full list.
    private var payingWithRow: some View {
        Button(action: { Haptics.light(); showPicker = true }) {
            HStack(spacing: 6) {
                if let method = draft.paymentMethod {
                    (Text(verbatim: "Paying with \(method.label) · ").foregroundColor(Palette.onInkSoft)
                        + Text("Change").fontWeight(.semibold).foregroundColor(Palette.onInk))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Add a way to pay")
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.onInk)
                }
                Spacer(minLength: 0)
            }
            .font(HDFont.caption)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isPaying)
        .accessibilityLabel(payingWithLabel)
    }

    private var payButton: some View {
        Button {
            guard canPay, !isPaying else { return }
            Haptics.medium()
            tappedApplePay = false
            onPay()
        } label: {
            ZStack {
                if isPaying && !tappedApplePay {
                    ProgressView().tint(Palette.onLacquer)
                } else {
                    Text(verbatim: payTitle)
                        .font(HDFont.bodyStrong.monospacedDigit())
                        .multilineTextAlignment(.center)
                }
            }
            .foregroundStyle(canPay ? Palette.onLacquer : Palette.onInkSoft)
            .padding(.horizontal, Space.s)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(canPay ? Palette.lacquerFill : Palette.inkLine, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(PressLift())
        .disabled(!canPay || isPaying)
        .accessibilityLabel(payTitle)
    }

    /// Black with white type, as Apple's guidelines ask. Drawn by hand: PassKit's button needs entitlements.
    private var applePayButton: some View {
        Button {
            guard let applePay, !isPaying, !app.isOffline else { return }
            Haptics.medium()
            tappedApplePay = true
            draft.paymentMethod = applePay
            onPay()
        } label: {
            ZStack {
                if isPaying && tappedApplePay {
                    ProgressView().tint(Color.white)
                } else {
                    HStack(spacing: 2) {
                        Image(systemName: "apple.logo")
                            .font(HDFont.sans(20, weight: .medium))
                            .offset(y: -1)
                        Text("Pay")
                            .font(HDFont.sans(22, weight: .medium))
                    }
                }
            }
            .foregroundStyle(Color.white)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color.black, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .strokeBorder(Palette.onInkSoft, lineWidth: 1)
            )
            .opacity(app.isOffline ? 0.5 : 1)
            .contentShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(PressLift())
        .disabled(isPaying || app.isOffline)
        .accessibilityLabel(applePayLabel)
    }

    // MARK: Derived

    private static let policy = "Cancel with more than 24 hours' notice and it's free. Less than that and she keeps half. She's already turned down other work for you. Not there when she arrives and it's the full amount."

    private var holdLine: String {
        "We hold \(Money.format(price.clientTotalCents)) on your card now. It's charged when \(pro.firstName) marks you done, or 12 hours after that if she forgets. Cancel in time and the hold just drops off."
    }

    private var notesLine: String? {
        let n = draft.inspoPhotos.count
        let photos: String? = n == 0 ? nil : (n == 1 ? "1 photo" : "\(n) photos")
        let notes: String? = draft.notes.isEmpty ? nil : "Notes added"
        let parts = [notes, photos].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func pick(_ method: PaymentMethod) {
        withAnimation(Motion.spring) { draft.paymentMethod = method }
    }

    // MARK: Errors, on ink

    @ViewBuilder
    private func errorCard(_ error: BookingFlowError) -> some View {
        switch error {
        case .declined:
            inkErrorCard(message: error.message, actionTitle: "Add a card") {
                // Stripe's sheet takes the new card itself, so go straight back to it.
                if let card = app.payments.checkoutCard { pick(card); onTryAgain() } else { showAddCard = true }
            }
        case .slotTaken:
            inkErrorCard(message: error.message, actionTitle: "Pick another", action: onPickAnotherTime)
        case .proUnavailable:
            inkErrorCard(message: error.message, actionTitle: "See who's free", action: onSeeWhosFree)
        case .other:
            inkErrorCard(message: error.message, actionTitle: "Try again", action: onTryAgain)
        }
    }

    private func inkErrorCard(message: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            InkNote(text: message)
            OutlineButton(title: actionTitle, tone: .onInk, compact: true, action: action)
                .fixedSize()
        }
        .padding(Space.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.inkRaised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Palette.inkLine, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Pay with

/// The full list of ways to pay, behind "Change" on the ticket. An ink sheet over the ink ticket:
/// rows with paper hairlines and a paper check on the one she's paying with.
private struct PaymentPickerSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: PaymentMethod?
    var holdLine: String

    @State private var showAddCard = false

    private var applePay: PaymentMethod? { ReviewStep.applePayMethod(in: app) }
    private var cards: [PaymentMethod] { ReviewStep.cardMethods(in: app) }

    var body: some View {
        VStack(spacing: 0) {
            InkSheetHeader(title: "Pay with", onClose: { dismiss() })

            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    VStack(spacing: 0) {
                        Rectangle().fill(Palette.inkLine).frame(height: 0.5)
                        if let applePay {
                            InkChoiceRow(isSelected: isPicked(applePay), action: { choose(applePay) }) {
                                ApplePayPill(height: 28).accessibilityHidden(true)
                                Text("Apple Pay").font(HDFont.body).foregroundStyle(Palette.onInk)
                            }
                        }
                        ForEach(cards) { card in
                            InkChoiceRow(isSelected: isPicked(card), action: { choose(card) }) {
                                Image(systemName: "creditcard")
                                    .font(.system(size: 17, weight: .light))
                                    .foregroundStyle(Palette.onInk)
                                    .frame(width: 28)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    if card.isDefault { Text("Default").eyebrowStyle(color: Palette.onInkSoft) }
                                    Text("\(card.brand) ending \(card.last4)").font(HDFont.body).foregroundStyle(Palette.onInk)
                                }
                            }
                        }
                        Button(action: {
                            Haptics.light()
                            if let card = app.payments.checkoutCard { choose(card) } else { showAddCard = true }
                        }) {
                            HStack(spacing: Space.m) {
                                Image(systemName: "plus")
                                    .font(.system(size: 17, weight: .light))
                                    .frame(width: 28)
                                Text("Add a card").font(HDFont.body)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(Palette.onInk)
                            .padding(.vertical, Space.m)
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Text(holdLine)
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.onInkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Card details go to Stripe, not to us.")
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.onInkSoft)
                }
                .screenGutter()
                .padding(.top, Space.s)
                .padding(.bottom, Space.xl)
            }
        }
        .background(Palette.inkGround.ignoresSafeArea())
        .presentationBackground(Palette.inkGround)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showAddCard) {
            AddCardSheet { method in
                withAnimation(Motion.spring) { selected = method }
                dismiss()
            }
        }
    }

    private func isPicked(_ method: PaymentMethod) -> Bool { selected?.id == method.id }

    private func choose(_ method: PaymentMethod) {
        withAnimation(Motion.spring) { selected = method }
        dismiss()
    }
}

/// One choice on an ink sheet: content, then a paper check when it's the one. Paper hairline under.
private struct InkChoiceRow<Content: View>: View {
    var isSelected: Bool
    var action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: { Haptics.selection(); action() }) {
            HStack(spacing: Space.m) {
                content()
                Spacer(minLength: 0)
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Palette.onInk)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Space.m)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.inkLine).frame(height: 0.5) }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Step 6: You're booked

/// Still on ink. The check draws itself (a clock, for a request), "You're booked." in serif, then
/// the record she keeps: paper, her work on top, who it's for, when, where, what, and a lacquer full stop.
///
/// Mockup 05 also shows "Add to Apple Wallet". That needs a signed pass (a Pass Type ID certificate and
/// a server to sign it), which we don't have, so the space is left out rather than faked.
struct BookedStep: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    var booking: Booking
    var pro: Pro
    /// How many inspo photos she picked, to say so if some didn't make it up.
    var photosPicked: Int = 0
    var onMessage: () -> Void
    var onDone: () -> Void

    @State private var drawn: CGFloat = 0

    private var isRequest: Bool { booking.status == .requested }

    private var title: String { isRequest ? "Requested." : "You're booked." }

    private var sub: String {
        if isRequest {
            return "\(pro.firstName) usually replies within \(pro.replyWindow). We'll ping you. Nothing's charged until she says yes."
        }
        if booking.isToday { return "Sit tight. \(pro.firstName)'s coming at \(booking.start.clock)." }
        return "\(pro.firstName), \(booking.start.friendlyDayInSentence) at \(booking.start.clock). We'll remind you the day before."
    }

    private var shareText: String {
        "I've got \(pro.firstName) coming \(booking.start.friendlyDayInSentence) at \(booking.start.clock), \(booking.address.short). Booked on Hair Done. Ref \(booking.reference)."
    }

    /// Some of her photos didn't upload. The booking stands; she can send them in the thread.
    private var photosMissing: Bool {
        app.isLive && photosPicked > 0 && booking.inspoURLs.count < photosPicked
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                mark
                    .padding(.top, Space.xs)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Space.s) {
                    Text(verbatim: title)
                        .font(HDFont.serif(42, relativeTo: .largeTitle))
                        .tracking(-0.5)
                        .foregroundStyle(Palette.onInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: sub)
                        .font(HDFont.body)
                        .foregroundStyle(Palette.onInk.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 18)
                .accessibilityElement(children: .combine)

                record
                    .padding(.top, 28)

                if photosMissing {
                    InkNote(text: "Your photos didn't all go through. Send them to \(pro.firstName) in Messages.")
                        .padding(.top, Space.l)
                }

                actions
                    .padding(.top, Space.xl)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.section)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Spacer()
                Button(action: { Haptics.light(); onDone() }) {
                    Text("Done")
                        .font(HDFont.bodyStrong)
                        .foregroundStyle(Palette.onInk)
                        .padding(.horizontal, 8)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Space.m)
            .padding(.top, Space.s)
            .background(Palette.inkGround)
        }
        .onAppear {
            if reduceMotion {
                drawn = 1
            } else {
                withAnimation(.easeInOut(duration: isRequest ? 0.8 : 0.55).delay(0.2)) { drawn = 1 }
            }
        }
    }

    /// The lacquer check for a confirmed booking; an outline clock that draws itself for a request
    /// (a tick would say "done" when it isn't yet).
    @ViewBuilder
    private var mark: some View {
        if isRequest {
            ZStack {
                Circle()
                    .trim(from: 0, to: drawn)
                    .stroke(Palette.onInk, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                ClockHands()
                    .trim(from: 0, to: drawn)
                    .stroke(Palette.onInk, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(width: 46, height: 46)
        } else {
            CheckShape()
                .trim(from: 0, to: drawn)
                .stroke(Palette.lacquer, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                .frame(width: 52, height: 38)
        }
    }

    @ViewBuilder
    private var actions: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: Space.m) {
                messageButton
                shareButton
            }
        } else {
            HStack(spacing: 13) {
                messageButton
                shareButton
            }
        }
    }

    private var messageButton: some View {
        OutlineButton(title: "Message \(pro.firstName)", tone: .onInk, action: onMessage)
    }

    /// ShareLink can't take a button style, so it wears the same outline.
    private var shareButton: some View {
        ShareLink(item: shareText) {
            Text("Share with a friend")
                .font(HDFont.bodyStrong)
                .foregroundStyle(Palette.onInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.l)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                        .strokeBorder(Palette.onInk, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(PressLift())
    }

    // MARK: The record

    private var forLine: String {
        if let first = app.client?.firstName, !first.isEmpty { return "For \(first)" }
        return "Your booking"
    }

    /// A different photo from the ticket's cover where she has one, in the booking's category.
    /// Nil when she has no photos of her own: the record shows the neutral tile, never stock work.
    private var recordPhoto: WorkItem? {
        let matching = pro.work.filter { $0.category == booking.primaryCategory }
        if matching.count > 1 { return matching[1] }
        return matching.first ?? pro.homeCover
    }

    /// "Tuesday 23 September"
    private static func longDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_AU")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: date)
    }

    /// Type on the record. The record is paper in both modes, so its type is the fixed ink ground.
    private var recordInk: Color { Palette.inkGround }
    private var recordInkSoft: Color { Palette.inkGround.opacity(0.68) }

    private var recordLines: Text {
        let when = "\(BookedStep.longDay(booking.start)), \(booking.start.clock)"
        let whereLine = "at yours in \(booking.address.suburb)"
        // Serif words, SF money: the amount carries its own font, so the caller's serif doesn't reach it.
        return Text(verbatim: "\(when)\n\(whereLine)\n\(booking.servicesLine) · ").foregroundColor(recordInk)
            + Text(verbatim: Money.format(booking.price.clientTotalCents))
                .font(HDFont.sans(19, relativeTo: .body).monospacedDigit())
                .foregroundColor(recordInk)
            + Text(verbatim: " held").foregroundColor(recordInk)
            + Text(verbatim: ".").fontWeight(.bold).foregroundColor(Palette.lacquerFill)
    }

    private var record: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomePhoto(item: recordPhoto, cornerRadius: 0)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .clipped()
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: forLine)
                    .eyebrowStyle(color: recordInkSoft)
                Text(verbatim: pro.displayName)
                    .font(HDFont.serif(32, relativeTo: .title1))
                    .foregroundStyle(recordInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                recordLines
                    .font(HDFont.quote)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            TicketTear(notchColor: Palette.inkGround, lineColor: recordInk.opacity(0.22))

            HStack(alignment: .firstTextBaseline) {
                Text("Reference")
                    .font(HDFont.caption)
                    .foregroundStyle(recordInkSoft)
                Spacer()
                Text(verbatim: booking.reference)
                    .font(HDFont.subStrong.monospacedDigit())
                    .foregroundStyle(recordInk)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 18)
        }
        .background(Palette.onInk)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Two hands at ten past ten, drawn from the centre, for the request clock.
private struct ClockHands: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r * 0.6))
        p.addLine(to: c)
        p.addLine(to: CGPoint(x: c.x + r * 0.42, y: c.y + r * 0.18))
        return p
    }
}

#Preview("Booked") {
    let app = previewApp()
    return Group {
        if let booking = app.upcomingBookings.first, let pro = app.pro(booking.proID) {
            BookedStep(booking: booking, pro: pro, onMessage: {}, onDone: {})
                .background(Palette.inkGround.ignoresSafeArea())
        }
    }
    .environment(app)
}
