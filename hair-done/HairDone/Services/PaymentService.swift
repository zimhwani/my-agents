import Foundation

/// Holds now, charges when she's done. The mock version just waits a beat and says yes.
protocol PaymentService: AnyObject {
    var supportsApplePay: Bool { get }
    /// Place a hold for the booking total. Returns an intent id to capture later.
    func authorise(amountCents: Int, method: PaymentMethod, bookingReference: String) async throws -> String
    func capture(intentID: String) async throws
    func cancelHold(intentID: String) async throws
    func addCard(number: String, expiry: String, cvc: String) async throws -> PaymentMethod
    /// Pro side: the onboarding link for Stripe Connect Express.
    func payoutOnboardingURL(proID: String) async throws -> URL
}

enum PaymentError: LocalizedError {
    case declined
    case cancelled
    case unavailable

    var errorDescription: String? {
        switch self {
        case .declined: return "Your card said no. Try another one, or Apple Pay."
        case .cancelled: return "No worries, nothing was charged."
        case .unavailable: return "Payments are having a moment. Try again in a minute."
        }
    }
}

final class MockPaymentService: PaymentService {
    var supportsApplePay: Bool { true }
    /// Set this to make the next authorisation fail, for testing the declined state.
    var failNext = false

    func authorise(amountCents: Int, method: PaymentMethod, bookingReference: String) async throws -> String {
        try await Task.sleep(for: .milliseconds(900))
        if failNext { failNext = false; throw PaymentError.declined }
        return "pi_mock_\(bookingReference)_\(Int(Date().timeIntervalSince1970))"
    }
    func capture(intentID: String) async throws { try await Task.sleep(for: .milliseconds(300)) }
    func cancelHold(intentID: String) async throws { try await Task.sleep(for: .milliseconds(300)) }
    func addCard(number: String, expiry: String, cvc: String) async throws -> PaymentMethod {
        try await Task.sleep(for: .milliseconds(700))
        let digits = number.filter(\.isNumber)
        guard digits.count >= 12 else { throw PaymentError.declined }
        let brand = digits.hasPrefix("4") ? "Visa" : digits.hasPrefix("5") ? "Mastercard" : digits.hasPrefix("3") ? "Amex" : "Card"
        return PaymentMethod(id: UUID().uuidString, kind: .card, brand: brand, last4: String(digits.suffix(4)), expiry: expiry, isDefault: false)
    }
    func payoutOnboardingURL(proID: String) async throws -> URL {
        URL(string: "https://connect.stripe.com/express/onboarding/mock")!
    }
}

#if canImport(StripePaymentSheet)
import StripePaymentSheet

/// Real payments. Add the `stripe-ios` package (StripePaymentSheet product) to the
/// target, set the publishable key, and swap this in for the mock in `AppState`.
/// The server side lives in `supabase/functions/create-payment-intent`.
final class StripePaymentService: PaymentService {
    let publishableKey: String
    let functionsBaseURL: URL
    var supportsApplePay: Bool { true }

    init(publishableKey: String, functionsBaseURL: URL) {
        self.publishableKey = publishableKey
        self.functionsBaseURL = functionsBaseURL
        STPAPIClient.shared.publishableKey = publishableKey
    }

    func authorise(amountCents: Int, method: PaymentMethod, bookingReference: String) async throws -> String {
        // 1. POST /create-payment-intent { amount, reference, capture_method: "manual" }
        // 2. Present PaymentSheet with the returned client secret.
        // 3. Return the PaymentIntent id.
        throw PaymentError.unavailable
    }
    func capture(intentID: String) async throws { throw PaymentError.unavailable }
    func cancelHold(intentID: String) async throws { throw PaymentError.unavailable }
    func addCard(number: String, expiry: String, cvc: String) async throws -> PaymentMethod { throw PaymentError.unavailable }
    func payoutOnboardingURL(proID: String) async throws -> URL {
        functionsBaseURL.appendingPathComponent("connect-onboarding")
    }
}
#endif
