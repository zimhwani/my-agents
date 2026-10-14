import SwiftUI

/// Add a card. The number formats itself in fours, the brand shows as you type, and Stripe holds the details.
struct AddCardSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    var onAdded: (PaymentMethod) -> Void

    @State private var number = ""
    @State private var expiry = ""
    @State private var cvc = ""
    @State private var isSaving = false
    @State private var problem: String? = nil

    private var digits: String { number.filter(\.isNumber) }
    private var brand: String? { CardBrand.detect(digits) }
    private var expiryIsValid: Bool {
        let parts = expiry.split(separator: "/")
        guard parts.count == 2, let month = Int(parts[0]), let year = Int(parts[1]) else { return false }
        guard (1...12).contains(month), parts[1].count == 2 else { return false }
        let now = Date()
        let thisYear = Calendar.current.component(.year, from: now) % 100
        let thisMonth = Calendar.current.component(.month, from: now)
        return year > thisYear || (year == thisYear && month >= thisMonth)
    }
    private var canSave: Bool { digits.count >= 12 && expiryIsValid && cvc.count >= 3 }

    var body: some View {
        VStack(spacing: 0) {
            InkSheetHeader(title: "Add a card", onClose: { dismiss() })

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    VStack(alignment: .leading, spacing: Space.l) {
                        InkField(
                            label: brand.map { "Card number · \($0)" } ?? "Card number",
                            placeholder: "1234 5678 9012 3456",
                            text: $number,
                            contentType: .creditCardNumber
                        )
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: Space.m) {
                                InkField(label: "Expiry", placeholder: "MM/YY", text: $expiry)
                                InkField(label: "CVC", placeholder: "123", text: $cvc)
                            }
                            VStack(alignment: .leading, spacing: Space.l) {
                                InkField(label: "Expiry", placeholder: "MM/YY", text: $expiry)
                                InkField(label: "CVC", placeholder: "123", text: $cvc)
                            }
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Image(systemName: "lock")
                            .font(.system(size: 13, weight: .light))
                            .accessibilityHidden(true)
                        Text("Cards are handled by Stripe. We never see the number.")
                            .font(HDFont.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Palette.onInkSoft)

                    if let problem {
                        InkNote(text: problem)
                            .transition(.opacity)
                    }
                }
                .screenGutter()
                .padding(.top, Space.m)
                .padding(.bottom, Space.xl)
                .animation(Motion.spring, value: problem)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(alignment: .leading, spacing: Space.s) {
                Text(canSave ? "Nothing's charged yet." : "Number, expiry and CVC.")
                    .font(HDFont.caption)
                    .foregroundStyle(Palette.onInkSoft)
                InkButton(title: "Add card", isLoading: isSaving, isEnabled: canSave && !app.isOffline, tone: .onInk, action: save)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.m)
            .padding(.bottom, Space.s)
            .overlay(alignment: .top) { Rectangle().fill(Palette.inkLine).frame(height: 0.5) }
        }
        .background(Palette.inkGround.ignoresSafeArea())
        .presentationBackground(Palette.inkGround)
        .holdsPushRoutes()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: number) { _, new in
            let formatted = CardBrand.group(new)
            if formatted != new { number = formatted }
        }
        .onChange(of: expiry) { _, new in
            let formatted = CardBrand.expiry(new)
            if formatted != new { expiry = formatted }
        }
        .onChange(of: cvc) { _, new in
            let trimmed = String(new.filter(\.isNumber).prefix(4))
            if trimmed != new { cvc = trimmed }
        }
    }

    private func save() {
        guard canSave, !isSaving else { return }
        withAnimation(Motion.gentle) { problem = nil }
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            do {
                let method = try await app.payments.addCard(number: digits, expiry: expiry, cvc: cvc)
                if var client = app.client {
                    client.paymentMethods.append(method)
                    app.client = client
                    try? await app.data.updateClient(client)
                }
                onAdded(method)
                dismiss()
            } catch PaymentError.declined {
                withAnimation(Motion.spring) {
                    problem = "That card didn't go through. Nothing's been charged. Try another, or Apple Pay."
                }
            } catch {
                withAnimation(Motion.spring) { problem = error.localizedDescription }
            }
        }
    }
}

/// A paper underline field on ink: label SF 13 in soft paper, SF 17 paper text, a hairline rule that
/// turns into a 2pt paper rule while focused. Number pad, because every field here is digits.
private struct InkField: View {
    var label: String
    var placeholder: String
    @Binding var text: String
    var contentType: UITextContentType? = nil

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(label)
                .font(HDFont.caption)
                .foregroundStyle(Palette.onInkSoft)
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Palette.onInk.opacity(0.35)))
                .font(HDFont.body.monospacedDigit())
                .foregroundStyle(Palette.onInk)
                .tint(Palette.onInk)
                .keyboardType(.numberPad)
                .textContentType(contentType)
                .focused($focused)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(focused ? Palette.onInk : Palette.onInk.opacity(0.3))
                        .frame(height: focused ? 2 : 1)
                        .animation(Motion.gentle, value: focused)
                }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Card number helpers: brand from the first digits, and the two formatters.
enum CardBrand {
    static func detect(_ digits: String) -> String? {
        guard !digits.isEmpty else { return nil }
        if digits.hasPrefix("4") { return "Visa" }
        if digits.hasPrefix("34") || digits.hasPrefix("37") { return "Amex" }
        if let two = Int(digits.prefix(2)), (51...55).contains(two) { return "Mastercard" }
        if let four = Int(digits.prefix(4)), (2221...2720).contains(four) { return "Mastercard" }
        return nil
    }

    /// "4242424242424242" → "4242 4242 4242 4242". Caps at 19 digits.
    static func group(_ raw: String) -> String {
        let digits = Array(raw.filter(\.isNumber).prefix(19))
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && i % 4 == 0 { out.append(" ") }
            out.append(ch)
        }
        return out
    }

    /// "0928" → "09/28". Tolerates a typed slash.
    static func expiry(_ raw: String) -> String {
        let digits = Array(raw.filter(\.isNumber).prefix(4))
        guard digits.count > 2 else { return String(digits) }
        return String(digits[0..<2]) + "/" + String(digits[2...])
    }
}

#Preview("Add a card") {
    Color.clear
        .sheet(isPresented: .constant(true)) { AddCardSheet { _ in } }
        .environment(previewApp())
}
