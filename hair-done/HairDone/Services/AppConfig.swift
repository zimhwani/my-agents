import Foundation

/// The backend settings, from Info.plist. They come from `HairDone.xcconfig` through project.yml
/// (`HDSupabaseURL` and friends). Any of them can be empty; the app then runs on its sample data.
enum AppConfig {
    static var supabaseURL: URL? {
        let raw = string("HDSupabaseURL")
        guard !raw.isEmpty, let url = URL(string: raw), url.scheme == "https" else { return nil }
        return url
    }
    static var supabaseKey: String { string("HDSupabaseKey") }
    static var stripeKey: String { string("HDStripeKey") }
    static var merchantID: String { string("HDMerchantID") }

    /// True when the app should talk to the real backend.
    static var hasBackend: Bool { supabaseURL != nil && !supabaseKey.isEmpty }

    /// Reads a string from Info.plist. An unset build setting arrives as "" or as the literal "$(NAME)".
    private static func string(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return "" }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("$(") { return "" }
        return trimmed
    }
}
