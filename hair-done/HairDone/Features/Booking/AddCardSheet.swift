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
            SheetHeader(title: "Add a card", onClose: { dismiss() })

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    VStack(alignment: .leading, spacing: Space.l) {
                        HDTextField(
                            label: brand.map { "Card number · \($0)" } ?? "Card number",
                            placeholder: "1234 5678 9012 3456",
                            text: $number,
                            keyboard: .numberPad,
                            contentType: .creditCardNumber
                        )
                        HStack(alignment: .top, spacing: Space.m) {
                            HDTextField(label: "Expiry", placeholder: "MM/YY", text: $expiry, keyboard: .numberPad)
                            HDTextField(label: "CVC", placeholder: "123", text: $cvc, keyboard: .numberPad)
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Image(systemName: "lock")
                            .font(.system(size: 13, weight: .medium))
                            .accessibilityHidden(true)
                        Text("Cards are handled by Stripe. We never see the number.")
                            .font(HDFont.caption)
                    }
                    .foregroundStyle(Palette.inkSoft)

                    if let problem {
                        InlineNote(text: problem, tone: .warn)
                            .transition(.opacity)
                    }
                }
                .screenGutter()
                .padding(.top, Space.m)
                .padding(.bottom, Space.xl)
                .animation(Motion.spring, value: problem)
            }
            .scrollDismissesKeyboard(.interactively)

            StickyBar(title: "Add card", isLoading: isSaving, isEnabled: canSave, action: save) {
                Text(canSave ? "Nothing's charged yet." : "Number, expiry and CVC.")
                    .font(HDFont.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .paperBackground()
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
