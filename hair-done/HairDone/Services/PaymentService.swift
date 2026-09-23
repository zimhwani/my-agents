import Foundation

/// Takes the money for a booking. The server has already made the booking and worked out the price;
/// this puts the card behind it: a hold now, or the card saved for a hold six days out. Charging,
/// releasing and cancellation charges all happen on the server's timers, never here.
protocol PaymentService: AnyObject {
    var supportsApplePay: Bool { get }
    /// When cards are taken in Stripe's own sheet at checkout there's no card form of ours:
    /// this stands in for "a card you'll add there". Nil when the app takes cards itself.
    var checkoutCard: PaymentMethod? { get }
    /// Pay for a booking that's just been made. Throws `PaymentError.cancelled` if she backs out.
    func checkout(booking: Booking, method: PaymentMethod) async throws
    func addCard(number: String, expiry: String, cvc: String) async throws -> PaymentMethod
    /// Pro side: the onboarding link for Stripe Connect Express.
    func payoutOnboardingURL(proID: String) async throws -> URL
}

enum PaymentError: LocalizedError {
    case declined
    case cancelled
    case unavailable
    case proNotReady

    var errorDescription: String? {
        switch self {
        case .declined: return "That card didn't go through. Nothing's been charged. Try another, or Apple Pay."
        case .cancelled: return "No worries, nothing was charged."
        case .unavailable: return "Couldn't place the hold. Nothing's been charged. Try again in a minute."
        case .proNotReady: return "She can't take bookings through the app just yet. Nothing's been charged. Try someone else for now."
        }
    }
}

final class MockPaymentService: PaymentService {
    var supportsApplePay: Bool { true }
    var checkoutCard: PaymentMethod? { nil }
    /// Set this to make the next checkout fail, for testing the declined state.
    var failNext = false

    func checkout(booking: Booking, method: PaymentMethod) async throws {
        try await Task.sleep(for: .milliseconds(900))
        if failNext { failNext = false; throw PaymentError.declined }
    }
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
import PassKit
import UIKit

/// Real payments through Stripe's PaymentSheet. The intents are made by the
/// `create-payment-intent` edge function; the card never touches our code.
final class StripePaymentService: PaymentService {
    let api: SupabaseAPI
    let merchantID: String
    /// Kept while the sheet is up.
    private var activeSheet: PaymentSheet? = nil

    init(publishableKey: String, merchantID: String, api: SupabaseAPI) {
        self.api = api
        self.merchantID = merchantID
        STPAPIClient.shared.publishableKey = publishableKey
    }

    var supportsApplePay: Bool { !merchantID.isEmpty && PKPaymentAuthorizationController.canMakePayments() }

    var checkoutCard: PaymentMethod? {
        PaymentMethod(id: "pm_checkout", kind: .card, brand: "Card", last4: "", expiry: "", isDefault: false)
    }

    private struct IntentReply: Decodable {
        let mode: String
        let clientSecret: String
        let customerId: String
        let ephemeralKey: String
    }

    private enum SheetOutcome { case completed, canceled, failed }

    func checkout(booking: Booking, method: PaymentMethod) async throws {
        let body = try SupabaseJSON.body(["booking_id": booking.id])
        let intent: IntentReply
        do {
            let data = try await api.call("POST", "functions/v1/create-payment-intent", body: body)
            intent = try SupabaseJSON.decode(IntentReply.self, from: data)
        } catch let failure as SupabaseFailure {
            if failure.says("already_paid") {
                // A retry after the card went through: just make sure the server knows.
                try await confirm(bookingID: booking.id)
                return
            }
            if failure.says("pro_payouts_not_set_up") { throw PaymentError.proNotReady }
            throw PaymentError.unavailable
        }

        let outcome = await present(intent)
        switch outcome {
        case .completed:
            try await confirm(bookingID: booking.id)
        case .canceled:
            // Nothing's charged; the unpaid booking lapses on the server by itself.
            throw PaymentError.cancelled
        case .failed:
            throw PaymentError.declined
        }
    }

    /// Tells the server the card's in, so the pro sees the request now rather than when the webhook lands.
    private func confirm(bookingID: String) async throws {
        let body = try SupabaseJSON.body(["booking_id": bookingID, "action": "confirm"])
        _ = try? await api.call("POST", "functions/v1/create-payment-intent", body: body)
    }

    @MainActor
    private func present(_ intent: IntentReply) async -> SheetOutcome {
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "Hair Done"
        configuration.customer = PaymentSheet.CustomerConfiguration(id: intent.customerId, ephemeralKeySecret: intent.ephemeralKey)
        configuration.allowsDelayedPaymentMethods = false
        configuration.returnURL = "hairdone://stripe-redirect"
        if !merchantID.isEmpty {
            configuration.applePay = PaymentSheet.ApplePayConfiguration(merchantId: merchantID, merchantCountryCode: "AU")
        }

        let sheet: PaymentSheet
        if intent.mode == "setup" {
            sheet = PaymentSheet(setupIntentClientSecret: intent.clientSecret, configuration: configuration)
        } else {
            sheet = PaymentSheet(paymentIntentClientSecret: intent.clientSecret, configuration: configuration)
        }
        guard let top = StripePaymentService.topViewController() else { return .failed }
        activeSheet = sheet

        let outcome: SheetOutcome = await withCheckedContinuation { continuation in
            sheet.present(from: top) { result in
                switch result {
                case .completed: continuation.resume(returning: .completed)
                case .canceled: continuation.resume(returning: .canceled)
                case .failed: continuation.resume(returning: .failed)
                }
            }
        }
        activeSheet = nil
        return outcome
    }

    /// The view controller on top of the active window, e.g. the booking flow's full-screen cover.
    @MainActor
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    /// Cards are taken in Stripe's sheet at checkout, not on our own form.
    func addCard(number: String, expiry: String, cvc: String) async throws -> PaymentMethod {
        throw PaymentError.unavailable
    }

    private struct LinkReply: Decodable { let url: String }

    func payoutOnboardingURL(proID: String) async throws -> URL {
        let data = try await api.call("GET", "functions/v1/connect-onboarding")
        let reply = try SupabaseJSON.decode(LinkReply.self, from: data)
        guard let url = URL(string: reply.url) else { throw PaymentError.unavailable }
        return url
    }
}
#endif

/// Returns from a bank's card check (3-D Secure) come back through `hairdone://stripe-redirect`.
enum PaymentRedirect {
    /// Hands the URL to Stripe. True if it was Stripe's to handle.
    static func handle(_ url: URL) -> Bool {
        #if canImport(StripePaymentSheet)
        return StripeAPI.handleURLCallback(with: url)
        #else
        return false
        #endif
    }
}
