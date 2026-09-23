import SwiftUI

/// Stars, a word, a line if you want, a tip if you want. Then thanks.
struct ReviewSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var booking: Booking

    @State private var rating = 0
    @State private var text = ""
    @State private var tip: TipChoice = .noTip
    @State private var customTip = ""
    @State private var sending = false
    @State private var sent = false
    @FocusState private var focus: Field?

    enum Field { case review, tip }

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

    private var pro: Pro? { app.pro(booking.proID) }
    private var proName: String { pro?.firstName ?? "her" }

    private var tipCents: Int {
        switch tip {
        case .noTip: return 0
        case .cents(let c): return c
        case .other:
            let digits = customTip.filter { $0.isNumber || $0 == "." }
            return Int(((Double(digits) ?? 0) * 100).rounded())
        }
    }

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
        rating > 0 && rating < 3 ? "What went wrong? We read these too." : "What was she like? The next woman deciding will read this."
    }

    /// On the real backend a done booking isn't charged until she pays here (or 12 hours pass).
    private var paying: Bool { app.isLive && booking.status == .done }

    /// A tip goes through with the payment, so on the real backend it's offered only until then.
    private var canTip: Bool { app.isLive ? booking.status == .done : booking.status.isFinished }

    private var sendTitle: String {
        if paying { return "Pay \(Money.format(booking.price.clientTotalCents + tipCents))" }
        return tipCents > 0 ? "Send and tip \(Money.format(tipCents))" : "Send"
    }

    private var thanksLine: String {
        if paying && rating > 2 {
            return "Paid. \(Money.format(booking.price.clientTotalCents + tipCents)) to \(proName), receipt in your inbox."
        }
        if paying { return "Paid. Thanks for telling us. A person will look at this." }
        if rating <= 2 { return "Thanks for telling us. A person will look at this." }
        if tipCents > 0 { return "Thanks. \(Money.format(tipCents)) to \(proName), on top of the rest." }
        return "Thanks. \(proName) will see it, and so will the next woman deciding."
    }

    var body: some View {
        ZStack {
            if sent { thanks.transition(.opacity.combined(with: .scale(scale: 0.96))) } else { form.transition(.opacity) }
        }
        .paperBackground()
        .animation(Motion.springSlow, value: sent)
    }

    // MARK: Form

    private var form: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "How'd \(proName) go?", subtitle: "\(booking.servicesLine) · \(booking.start.friendlyDay)", onClose: { dismiss() })
            ScrollView {
                VStack(spacing: Space.xl) {
                    Avatar(name: proName, seed: pro?.seed ?? 0, size: 72)
                        .padding(.top, Space.s)

                    VStack(spacing: Space.m) {
                        ZStack {
                            HoneyGlow(strength: Double(rating) / 5)
                            StarPicker(rating: $rating, size: 44)
                        }
                        Text(reaction)
                            .font(HDFont.serifItalic)
                            .foregroundStyle(Palette.ink)
                            .contentTransition(.opacity)
                            .id(rating)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                            .frame(minHeight: 28)
                            .accessibilityLabel(rating == 0 ? "Pick a star rating" : "\(rating) stars. \(reaction)")
                    }
                    .animation(reduceMotion ? nil : Motion.spring, value: rating)

                    if rating > 0 {
                        VStack(alignment: .leading, spacing: Space.s) {
                            TextField(placeholder, text: $text, axis: .vertical)
                                .font(HDFont.body)
                                .lineLimit(3...6)
                                .focused($focus, equals: .review)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                                .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: Radius.input, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
                            Text("Optional").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        if canTip {
                            tipSection.transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .screenGutter()
                .padding(.bottom, Space.section)
            }
            .scrollDismissesKeyboard(.interactively)
            .animation(reduceMotion ? nil : Motion.spring, value: rating > 0)

            VStack(spacing: Space.s) {
                PrimaryButton(title: sendTitle, isLoading: sending, isEnabled: rating > 0) { send() }
                TertiaryButton(title: "Not now") { dismiss() }
            }
            .screenGutter()
            .padding(.top, Space.s)
            .padding(.bottom, Space.l)
            .background(Palette.paper)
        }
    }

    private var tipSection: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Tip \(proName)").font(HDFont.heading).foregroundStyle(Palette.ink)
            Text("Optional. All of it goes to her.").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(tipChoices, id: \.self) { choice in
                        Chip(title: choice.label, isSelected: tip == choice) {
                            withAnimation(Motion.spring) { tip = choice }
                            if choice == .other { focus = .tip }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .padding(.horizontal, -Space.gutter)
            .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
            if tip == .other {
                HStack(spacing: 6) {
                    Text("$").font(HDFont.price).foregroundStyle(Palette.inkSoft)
                    TextField("Amount", text: $customTip)
                        .font(HDFont.price)
                        .keyboardType(.decimalPad)
                        .focused($focus, equals: .tip)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.input, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
                .frame(maxWidth: 160)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Thanks

    private var thanks: some View {
        VStack(spacing: Space.l) {
            Spacer()
            LacquerCheck(size: 72)
            Text(thanksLine)
                .font(HDFont.heading)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .screenGutter()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Closes")
        .task {
            try? await Task.sleep(for: .seconds(1.4))
            dismiss()
        }
    }

    // MARK: Send

    private func send() {
        guard rating > 0, !sending else { return }
        sending = true
        focus = nil
        Task {
            let done = await app.review(booking, rating: rating, text: text.trimmingCharacters(in: .whitespacesAndNewlines), tipCents: tipCents)
            sending = false
            if done { sent = true }
        }
    }
}

/// A soft honey wash behind the stars that grows as they fill.
struct HoneyGlow: View {
    var strength: Double
    var body: some View {
        Circle()
            .fill(Palette.honey)
            .frame(width: 180, height: 180)
            .blur(radius: 40)
            .opacity(0.10 + strength * 0.25)
            .scaleEffect(0.6 + strength * 0.6)
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#Preview("Review") {
    ReviewSheet(booking: MockData.bookings()[4]).environment(previewApp())
}
