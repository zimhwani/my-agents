import SwiftUI

// MARK: - The ink ground

/// Paper for browsing, ink for committing. "Check it over" and "You're booked." sit on ink in
/// light and dark alike, so these are fixed values, not Palette tokens (which flip in dark mode).
/// Lacquer stays `Palette.lacquer`, and only on Pay and the check.
enum BookingInk {
    static let inkGround = Color(hex: 0x241A16)
    static let onInk = Color(hex: 0xF4ECE4)
    static let onInkSoft = BookingInk.onInk.opacity(0.62)
    static let inkLine = BookingInk.onInk.opacity(0.14)
    static let inkCard = Color(hex: 0x2E2521)

    // The record she keeps: paper on ink, ink type.
    static let recordPaper = Color(hex: 0xF4ECE4)
    static let recordInk = Color(hex: 0x241A16)
    static let recordInkSoft = Color(hex: 0x6F625B)

    /// New York at a fixed design size that still follows Dynamic Type.
    static func serif(_ size: CGFloat, relativeTo style: UIFont.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        Font.system(size: UIFontMetrics(forTextStyle: style).scaledValue(for: size), weight: weight, design: .serif)
    }

    /// SF Pro at a fixed design size that still follows Dynamic Type.
    static func sans(_ size: CGFloat, relativeTo style: UIFont.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        Font.system(size: UIFontMetrics(forTextStyle: style).scaledValue(for: size), weight: weight, design: .default)
    }
}

/// A bare glyph button for ink chrome: no disc, no hairline.
struct BookingInkIconButton: View {
    var symbol: String
    var label: String
    var tint: Color = BookingInk.onInk
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.light(); action() }) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressLift(scale: 0.92))
        .accessibilityLabel(label)
    }
}

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
/// Ink, like a ticket. Pay in lacquer and Apple Pay side by side at the bottom.
struct ReviewStep: View {
    @Environment(AppState.self) private var app
    @Binding var draft: BookingDraft
    var error: BookingFlowError? = nil
    var onEdit: (BookingStep) -> Void
    var onPickAnotherTime: () -> Void
    var onTryAgain: () -> Void
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
                        .font(BookingInk.sans(13, relativeTo: .footnote))
                        .foregroundStyle(BookingInk.onInkSoft)
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

    private var cover: WorkItem {
        pro.work.first(where: { $0.isPinned }) ?? pro.work.first
            ?? WorkItem(id: "cover_\(pro.id)", category: pro.primaryCategory, caption: pro.displayName, seed: pro.seed)
    }

    private var ticket: some View {
        VStack(alignment: .leading, spacing: 0) {
            WorkTile(item: cover, cornerRadius: 0)
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .clipped()
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Space.s) {
                Text(verbatim: "\(pro.firstName) at yours.")
                    .font(BookingInk.serif(30, relativeTo: .largeTitle))
                    .tracking(-0.3)
                    .foregroundStyle(BookingInk.onInk)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: 0) {
                    if let start = draft.start {
                        detailRow("\(start.friendlyDayTime) · \(ReviewStep.shortDuration(draft.minutes))", changeLabel: "Change time") {
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

            TicketTear(notchColor: BookingInk.inkGround, lineColor: BookingInk.onInk.opacity(0.22))

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
                lineItem("Hair Done fee", amount: Money.format(price.bookingFeeCents))

                Rectangle()
                    .fill(BookingInk.inkLine)
                    .frame(height: 1)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                        Text("Total")
                            .font(BookingInk.sans(17))
                            .foregroundStyle(BookingInk.onInk)
                        Spacer(minLength: 0)
                        Text(Money.format(price.clientTotalCents))
                            .font(BookingInk.sans(36, relativeTo: .largeTitle).monospacedDigit())
                            .tracking(-0.6)
                            .foregroundStyle(BookingInk.onInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text(isPaying ? "Sorting it." : "Held now, charged when she's done.")
                        .font(BookingInk.sans(13, relativeTo: .footnote))
                        .foregroundStyle(BookingInk.onInkSoft)
                }
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(BookingInk.inkCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .strokeBorder(BookingInk.onInk.opacity(0.10), lineWidth: 0.5)
        )
    }

    private func detailRow(_ text: String, changeLabel: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            Text(verbatim: text)
                .font(BookingInk.sans(15, relativeTo: .subheadline))
                .foregroundStyle(BookingInk.onInk.opacity(0.8))
                .lineLimit(2)
            Spacer(minLength: 0)
            Button(action: { Haptics.light(); action() }) {
                Text("Change")
                    .font(BookingInk.sans(15, relativeTo: .subheadline))
                    .foregroundStyle(BookingInk.onInk.opacity(0.5))
                    .frame(minHeight: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(changeLabel)
        }
    }

    private func lineItem(_ label: String, amount: String, note: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                Text(verbatim: label)
                    .font(BookingInk.sans(17))
                    .foregroundStyle(BookingInk.onInk)
                Spacer(minLength: 0)
                Text(verbatim: amount)
                    .font(BookingInk.sans(17).monospacedDigit())
                    .foregroundStyle(BookingInk.onInk)
            }
            if let note {
                Text(verbatim: note)
                    .font(BookingInk.sans(13, relativeTo: .footnote))
                    .foregroundStyle(BookingInk.onInkSoft)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Paying

    private var payTitle: String {
        let total = Money.format(price.clientTotalCents)
        return pro.instantBook ? "Pay \(total)" : "Request · \(total)"
    }

    private var canPay: Bool { draft.paymentMethod != nil }

    private var payingWithLabel: String {
        guard let method = draft.paymentMethod else { return "Add a way to pay" }
        return "Paying with \(method.label). Change"
    }

    private var applePayLabel: String { pro.instantBook ? "Pay with Apple Pay" : "Request with Apple Pay" }

    private var payBar: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            payingWithRow
            HStack(spacing: 13) {
                payButton
                if applePay != nil { applePayButton }
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.s)
        .padding(.bottom, Space.s)
        .background(BookingInk.inkGround.ignoresSafeArea(.container, edges: .bottom))
    }

    /// "Paying with Apple Pay · Change". Opens the full list.
    private var payingWithRow: some View {
        Button(action: { Haptics.light(); showPicker = true }) {
            HStack(spacing: 6) {
                if let method = draft.paymentMethod {
                    Text(verbatim: "Paying with \(method.label)")
                        .foregroundStyle(BookingInk.onInkSoft)
                    Text(verbatim: "·")
                        .foregroundStyle(BookingInk.onInkSoft)
                    Text("Change")
                        .fontWeight(.semibold)
                        .foregroundStyle(BookingInk.onInk)
                } else {
                    Text("Add a way to pay")
                        .fontWeight(.semibold)
                        .foregroundStyle(BookingInk.onInk)
                }
                Spacer(minLength: 0)
            }
            .font(BookingInk.sans(13, relativeTo: .footnote))
            .lineLimit(1)
            .frame(minHeight: 36)
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
                        .font(BookingInk.sans(17, weight: .semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(canPay ? Palette.onLacquer : BookingInk.onInkSoft)
            .padding(.horizontal, Space.s)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(canPay ? Palette.lacquer : BookingInk.inkLine, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(PressLift())
        .disabled(!canPay || isPaying)
        .accessibilityLabel(payTitle)
    }

    /// Black with white type, as Apple's guidelines ask. Drawn by hand: PassKit's button needs entitlements.
    private var applePayButton: some View {
        Button {
            guard let applePay, !isPaying else { return }
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
                            .font(BookingInk.sans(20, weight: .medium))
                            .offset(y: -1)
                        Text("Pay")
                            .font(BookingInk.sans(22, weight: .medium))
                    }
                }
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.black, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .strokeBorder(BookingInk.onInkSoft, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(PressLift())
        .disabled(isPaying)
        .accessibilityLabel(applePayLabel)
    }

    // MARK: Derived

    private static let policy = "Cancel with more than 24 hours' notice and it's free. Less than that and she keeps half. She's already turned down other work for you. Not there when she arrives and it's the full amount."

    private var holdLine: String {
        "We hold \(Money.format(price.clientTotalCents)) on your card now. It's charged when \(pro.firstName) marks you done, or 12 hours after that if she forgets. Cancel in time and the hold just drops off."
    }

    private var notesLine: String? {
        let n = draft.inspoSeeds.count
        let photos: String? = n == 0 ? nil : (n == 1 ? "1 photo" : "\(n) photos")
        let notes: String? = draft.notes.isEmpty ? nil : "Notes added"
        let parts = [notes, photos].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// 75 → "1 h 15", 60 → "1 h", 45 → "45 min". The ticket's short form.
    private static func shortDuration(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h) h" }
        return "\(h) h \(m)"
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
        case .other:
            inkErrorCard(message: error.message, actionTitle: "Try again", action: onTryAgain)
        }
    }

    private func inkErrorCard(message: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                Image(systemName: "exclamationmark.circle")
                    .font(BookingInk.sans(15, relativeTo: .subheadline, weight: .medium))
                    .accessibilityHidden(true)
                Text(verbatim: message)
                    .font(BookingInk.sans(15, relativeTo: .subheadline))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(BookingInk.onInk)

            Button(action: { Haptics.light(); action() }) {
                Text(verbatim: actionTitle)
                    .font(BookingInk.sans(15, relativeTo: .subheadline, weight: .semibold))
                    .underline()
                    .foregroundStyle(BookingInk.onInk)
                    .frame(minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 23)
        }
        .padding(Space.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookingInk.inkCard, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .strokeBorder(BookingInk.inkLine, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

/// The full list of ways to pay, behind "Change" on the ticket. Same choices as before, in a sheet.
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
            SheetHeader(title: "Pay with", onClose: { dismiss() })

            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    VStack(spacing: 0) {
                        if let applePay {
                            PaymentRow(isSelected: isPicked(applePay), action: { choose(applePay) }) {
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
                            PaymentRow(isSelected: isPicked(card), action: { choose(card) }) {
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
                        Button(action: {
                            Haptics.light()
                            if let card = app.payments.checkoutCard { choose(card) } else { showAddCard = true }
                        }) {
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

                    Text(holdLine)
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.inkSoft)
                    Text("Card details go to Stripe, not to us.")
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.inkFaint)
                }
                .screenGutter()
                .padding(.top, Space.s)
                .padding(.bottom, Space.xl)
            }
        }
        .paperBackground()
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showAddCard) {
            AddCardSheet { method in
                withAnimation(Motion.spring) { selected = method }
            }
        }
    }

    private func isPicked(_ method: PaymentMethod) -> Bool { selected?.id == method.id }

    private func choose(_ method: PaymentMethod) {
        withAnimation(Motion.spring) { selected = method }
        dismiss()
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

/// Still on ink. The check draws itself, "You're booked." in serif, then the record she keeps:
/// paper, her work on top, who it's for, when, where, what, and a lacquer full stop.
struct BookedStep: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var booking: Booking
    var pro: Pro
    var onMessage: () -> Void
    var onDone: () -> Void

    @State private var drawn: CGFloat = 0

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
            VStack(alignment: .leading, spacing: 0) {
                CheckShape()
                    .trim(from: 0, to: drawn)
                    .stroke(Palette.lacquer, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 52, height: 38)
                    .padding(.top, Space.xs)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Space.s) {
                    Text(verbatim: title)
                        .font(BookingInk.serif(42, relativeTo: .largeTitle))
                        .tracking(-0.5)
                        .foregroundStyle(BookingInk.onInk)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: sub)
                        .font(BookingInk.sans(17))
                        .foregroundStyle(BookingInk.onInk.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 18)
                .accessibilityElement(children: .combine)

                record
                    .padding(.top, 28)

                HStack(spacing: 13) {
                    Button(action: { Haptics.light(); onMessage() }) {
                        outlineLabel("Message \(pro.firstName)")
                    }
                    .buttonStyle(PressLift())

                    ShareLink(item: shareText) {
                        outlineLabel("Share with a friend")
                    }
                    .buttonStyle(PressLift())
                }
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
                        .font(BookingInk.sans(17, weight: .semibold))
                        .foregroundStyle(BookingInk.onInk)
                        .padding(.horizontal, 8)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Space.m)
            .padding(.top, Space.s)
            .background(BookingInk.inkGround)
        }
        .onAppear {
            if reduceMotion {
                drawn = 1
            } else {
                withAnimation(.easeInOut(duration: 0.55).delay(0.2)) { drawn = 1 }
            }
        }
    }

    // MARK: The record

    private var forLine: String {
        if let first = app.client?.firstName, !first.isEmpty { return "For \(first)" }
        return "Your booking"
    }

    /// A different photo from the ticket's cover where she has one, in the booking's category.
    private var recordPhoto: WorkItem {
        let matching = pro.work.filter { $0.category == booking.primaryCategory }
        if matching.count > 1 { return matching[1] }
        return matching.first ?? pro.work.first
            ?? WorkItem(id: "record_\(booking.id)", category: booking.primaryCategory, caption: pro.displayName, seed: pro.seed)
    }

    /// "Tuesday 23 September"
    private static func longDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_AU")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: date)
    }

    private var recordLines: Text {
        let when = "\(BookedStep.longDay(booking.start)), \(booking.start.clock)"
        let whereLine = "at yours in \(booking.address.suburb)"
        let what = "\(booking.servicesLine) · \(Money.format(booking.price.clientTotalCents)) held"
        return Text(verbatim: "\(when)\n\(whereLine)\n\(what)").foregroundStyle(BookingInk.recordInk)
            + Text(verbatim: ".").fontWeight(.bold).foregroundStyle(Palette.lacquer)
    }

    private var record: some View {
        VStack(alignment: .leading, spacing: 0) {
            WorkTile(item: recordPhoto, cornerRadius: 0)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .clipped()
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: forLine)
                    .font(BookingInk.sans(12, relativeTo: .caption1, weight: .medium))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(BookingInk.recordInkSoft)
                Text(verbatim: pro.displayName)
                    .font(BookingInk.serif(32, relativeTo: .title1))
                    .foregroundStyle(BookingInk.recordInk)
                    .padding(.top, 4)
                recordLines
                    .font(BookingInk.serif(19, relativeTo: .title3))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            TicketTear(notchColor: BookingInk.inkGround, lineColor: BookingInk.recordInk.opacity(0.22))

            HStack(alignment: .firstTextBaseline) {
                Text("Reference")
                    .font(BookingInk.sans(13, relativeTo: .footnote))
                    .foregroundStyle(BookingInk.recordInkSoft)
                Spacer()
                Text(verbatim: booking.reference)
                    .font(BookingInk.sans(15, relativeTo: .subheadline, weight: .semibold).monospacedDigit())
                    .foregroundStyle(BookingInk.recordInk)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 18)
        }
        .background(BookingInk.recordPaper)
        .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func outlineLabel(_ title: String) -> some View {
        Text(verbatim: title)
            .font(BookingInk.sans(16, weight: .medium))
            .foregroundStyle(BookingInk.onInk)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, Space.s)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .strokeBorder(BookingInk.onInk.opacity(0.28), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
    }
}

/// Who, when, where, what, and the reference, on a paper card.
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
                .background(BookingInk.inkGround.ignoresSafeArea())
        }
    }
    .environment(app)
}
