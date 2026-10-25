import SwiftUI

/// "Pay Kiara", at done: the total, a tip if she wants, `Pay $X`, and "Something wrong?" under it.
/// Once it's paid the sheet turns into the receipt line, with the stars underneath as optional:
/// "How was she? Two taps." Paying never waits on a rating (audit M12).
struct PaySheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The booking as it was when the sheet opened; the live copy is looked up by id.
    var booking: Booking

    @State private var tip: TipChoice = .noTip
    @State private var customTip = ""
    @State private var paying = false
    @State private var paidCents: Int? = nil
    @State private var problem: String? = nil
    @State private var confirmFlag = false

    // After paying
    @State private var rating = 0
    @State private var reviewText = ""
    @State private var sendingReview = false
    @State private var reviewed = false
    @State private var reviewProblem: String? = nil

    enum TipChoice: Hashable {
        case noTip, cents(Int), other
        var label: String {
            switch self {
            case .noTip: return "No tip"
            case .cents(let c): return Money.format(c)
            case .other: return "Other"
            }
        }
    }

    private let tipChoices: [TipChoice] = [.noTip, .cents(1000), .cents(2000), .cents(3000), .other]

    private var current: Booking { app.bookings.first { $0.id == booking.id } ?? booking }
    private var pro: Pro? { app.pro(booking.proID) }
    private var proName: String { pro?.firstName ?? "your pro" }

    private var tipCents: Int {
        switch tip {
        case .noTip: return 0
        case .cents(let c): return c
        case .other:
            let digits = customTip.filter { $0.isNumber || $0 == "." }
            return max(0, Int(((Double(digits) ?? 0) * 100).rounded()))
        }
    }

    private var totalCents: Int { current.price.clientTotalCents + tipCents }

    var body: some View {
        ZStack {
            if let paidCents {
                paid(paidCents).transition(.opacity)
            } else if current.status == .paid {
                paid(current.price.clientTotalCents).transition(.opacity)
            } else {
                form.transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : Motion.springSlow, value: paidCents)
        .paperBackground()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.paper)
        .holdsPushRoutes()
        .confirmSheet(isPresented: $confirmFlag,
                      title: "Something wrong?",
                      message: "We'll hold off charging your card for up to 48 hours while a person looks. Then message us from Help and say what happened.",
                      confirmTitle: "Hold off the charge",
                      cancelTitle: "Leave it") {
            Task {
                if await app.flag(current, detail: "") {
                    dismiss()
                    app.show("Held off. A person will be in touch within two days.")
                }
            }
        }
    }

    // MARK: Pay

    private var form: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Pay \(proName)",
                        subtitle: "\(current.servicesLine) · \(current.start.friendlyDay)",
                        onClose: { dismiss() })
            if app.isOffline { OfflineBar() }
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    receipt
                    tipSection
                }
                .screenGutter()
                .padding(.top, Space.s)
                .padding(.bottom, Space.section)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: Space.xs) {
                if let problem {
                    FieldMessage(text: problem)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, Space.xs)
                        .transition(.opacity)
                }
                PrimaryButton(title: "Pay \(Money.format(totalCents))", isLoading: paying, isEnabled: !app.isOffline) { pay() }
                TertiaryButton(title: "Something wrong?") { confirmFlag = true }
                    .disabled(paying || app.isOffline)
            }
            .screenGutter()
            .padding(.top, Space.s)
            .padding(.bottom, Space.s)
            .background(Palette.paper)
        }
    }

    private var receipt: some View {
        VStack(spacing: 0) {
            ForEach(current.services) { s in receiptRow(s.name, cents: s.priceCents) }
            receiptRow("Travel fee", cents: current.price.travelFeeCents)
            receiptRow("Booking fee", cents: current.price.bookingFeeCents)
            if tipCents > 0 { receiptRow("Tip", cents: tipCents) }
            HStack(alignment: .firstTextBaseline) {
                Text("Total").font(HDFont.body).foregroundStyle(Palette.ink)
                Spacer()
                Text(Money.format(totalCents))
                    .font(HDFont.priceTotal)
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                    .animation(Motion.gentle, value: totalCents)
            }
            .padding(.top, Space.m)
            .accessibilityElement(children: .combine)
            Text("Charged to the card you booked with. Or we'll charge it at \(current.autoChargeAt.clock) if you leave it.")
                .font(HDFont.caption)
                .foregroundStyle(Palette.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.s)
        }
    }

    private func receiptRow(_ label: String, cents: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            Spacer(minLength: Space.m)
            Text(Money.format(cents)).font(HDFont.price).foregroundStyle(Palette.ink)
        }
        .padding(.vertical, Space.s + 2)
        .overlay(alignment: .bottom) { Hairline(strong: true) }
        .accessibilityElement(children: .combine)
    }

    private var tipSection: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Tip \(proName)").font(HDFont.name).foregroundStyle(Palette.ink)
            Text("Optional. All of it goes to them.").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(tipChoices, id: \.self) { choice in
                        OptionBox(title: choice.label, isSelected: tip == choice) {
                            withAnimation(Motion.spring) { tip = choice }
                        }
                        .fixedSize()
                    }
                }
                .padding(.vertical, 2)
            }
            .padding(.horizontal, -Space.gutter)
            .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
            .padding(.top, Space.xs)
            if tip == .other {
                HDTextField(label: "Amount", placeholder: "$15", text: $customTip, keyboard: .decimalPad)
                    .frame(maxWidth: 180, alignment: .leading)
                    .transition(.opacity)
            }
        }
    }

    private func pay() {
        guard !paying else { return }
        paying = true
        withAnimation(Motion.gentle) { problem = nil }
        let amount = totalCents
        let tipping = tipCents
        Task { @MainActor in
            let ok = await app.pay(current, tipCents: tipping)
            paying = false
            if ok {
                paidCents = amount
            } else {
                Haptics.warning()
                withAnimation(Motion.gentle) {
                    problem = app.lastError ?? "That didn't go through. Your card hasn't been charged. Try again in a minute."
                }
            }
        }
    }

    // MARK: Paid

    private func paid(_ cents: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                IconButton(symbol: "xmark", label: "Close") { dismiss() }
            }
            .padding(.horizontal, Space.gutter - 12)
            .padding(.top, Space.s)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    LacquerCheck(size: 56)
                        .padding(.top, Space.l)
                    // The sentence is serif; the amount is SF (money is never serif).
                    (Text("Paid. ")
                        + Text(verbatim: Money.format(cents)).font(HDFont.priceTotal)
                        + Text(" to \(proName), receipt in your inbox."))
                        .font(HDFont.titleSmall)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    if reviewed {
                        Text(rating <= 2 ? "Thanks for telling us. A person will look at this."
                                         : "Thanks. \(proName) will see it, and so will the next woman deciding.")
                            .font(HDFont.quote)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    } else if current.review == nil {
                        stars
                    }
                }
                .screenGutter()
                .padding(.bottom, Space.section)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: Space.xs) {
                if let reviewProblem {
                    FieldMessage(text: reviewProblem).frame(maxWidth: .infinity, alignment: .leading)
                }
                if rating > 0 && !reviewed {
                    InkButton(title: "Send", isLoading: sendingReview, isEnabled: !app.isOffline) { sendReview() }
                }
                TertiaryButton(title: reviewed || rating == 0 ? "Done" : "Not now") { dismiss() }
            }
            .screenGutter()
            .padding(.bottom, Space.s)
        }
    }

    private var stars: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Hairline(strong: true).padding(.vertical, Space.s)
            Text("How was \(proName)? Two taps.").font(HDFont.name).foregroundStyle(Palette.ink)
            StarPicker(rating: $rating, size: 36)
            if rating > 0 {
                Text(reaction)
                    .font(HDFont.serifItalic)
                    .foregroundStyle(Palette.ink)
                    .accessibilityLabel("\(rating) stars. \(reaction)")
                HDTextField(label: "A line, if you want",
                            placeholder: rating < 3 ? "What went wrong? We read these too." : "What were they like? The next person deciding will read this.",
                            text: $reviewText, axis: .vertical, caption: "Optional")
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : Motion.spring, value: rating > 0)
    }

    /// Copy deck `rate.stars.{n}`.
    private var reaction: String {
        switch rating {
        case 1: return "Not good."
        case 2: return "Not great."
        case 3: return "Fine."
        case 4: return "Good."
        default: return "Very good."
        }
    }

    private func sendReview() {
        guard rating > 0, !sendingReview else { return }
        sendingReview = true
        reviewProblem = nil
        Task { @MainActor in
            let outcome = await app.review(current, rating: rating,
                                           text: reviewText.trimmingCharacters(in: .whitespacesAndNewlines), tipCents: 0)
            sendingReview = false
            switch outcome {
            case .saved, .paidOnly:
                withAnimation(Motion.gentle) { reviewed = true }
                try? await Task.sleep(for: .seconds(1.6))
                dismiss()
            case .failed(let line):
                Haptics.warning()
                reviewProblem = line
            }
        }
    }
}

#Preview("Pay") {
    let app = previewApp()
    var b = MockData.bookings()[0]
    b.status = .done
    app.bookings = [b]
    return Color.clear.sheet(isPresented: .constant(true)) { PaySheet(booking: b) }.environment(app)
}
