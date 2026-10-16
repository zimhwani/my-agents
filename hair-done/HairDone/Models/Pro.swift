import Foundation
import CoreLocation

/// A mobile pro: the person who comes to you.
struct Pro: Identifiable, Hashable, Codable {
    let id: String
    var firstName: String
    var lastInitial: String
    var specialties: [Category]
    /// One line under her name, in her own words. "Nails, done properly, at your kitchen table."
    var headline: String
    var bio: String
    var suburb: String
    var latitude: Double
    var longitude: Double
    var travelRadiusKm: Double
    var travelFeeCents: Int
    var rating: Double
    var reviewCount: Int
    var isVerified: Bool
    var instantBook: Bool
    var yearsExperience: Int
    /// Typical reply time in minutes.
    var responseMinutes: Int
    var joined: Date
    var services: [Service]
    var work: [WorkItem]
    var reviews: [Review]
    var availability: WeeklyAvailability
    /// Seed for the procedural placeholder art and avatar tint. Stable per pro.
    var seed: Int
    /// Whether she's taking bookings right now.
    var isActive: Bool = true
    var completedBookings: Int = 0
    var reliabilityScore: Double = 1.0
    var abn: String = ""
    var payoutsConnected: Bool = false
    /// How much notice she needs before a job, in minutes (60 to 2880).
    var noticeMinutes: Int = 90
    /// False while she's still in onboarding: a draft clients can't see.
    var isOnboarded: Bool = true
    /// She closed her pro profile. Her work and prices are kept if she comes back.
    var isClosed: Bool = false
    /// She's sent photo ID and a selfie. `isVerified` is the server's yes, after a person has looked.
    var idSubmitted: Bool = false
    var avatarURL: URL? = nil

    /// "Kiara M.", or just "Kiara" when there's no last initial. Only a letter counts as one, so a
    /// stray space, newline or full stop can't give "Kiara ." (or "Kiara ..").
    var displayName: String {
        guard let initial = lastInitial.trimmingCharacters(in: .whitespacesAndNewlines).first, initial.isLetter else { return firstName }
        return "\(firstName) \(initial)."
    }
    var primaryCategory: Category { specialties.first ?? .hair }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }

    /// "Nail tech · Brunswick"
    var specialtyLine: String {
        let titles = specialties.prefix(2).map(\.specialtyTitle).joined(separator: " & ")
        return "\(titles) · \(suburb)"
    }

    var cheapestServiceCents: Int { services.map(\.priceCents).min() ?? 0 }

    func distanceKm(from coordinate: CLLocationCoordinate2D) -> Double {
        let a = CLLocation(latitude: latitude, longitude: longitude)
        let b = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return a.distance(from: b) / 1000
    }

    static func == (lhs: Pro, rhs: Pro) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// The two photos for the ID check. The raw value is the file name in her `id-docs` folder.
enum IDDocumentKind: String, CaseIterable {
    case photoID = "photo-id", selfie
}

/// Something a pro offers, with a price and how long it takes.
struct Service: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var category: Category
    var priceCents: Int
    var minutes: Int
    var detail: String
    var isPopular: Bool = false

    var priceLabel: String { Money.format(priceCents) }
    var durationLabel: String { minutes.minutesLabel }
}

/// One photo of a pro's work. `imageURL` is nil in the mock and the tile draws placeholder art.
struct WorkItem: Identifiable, Hashable, Codable {
    let id: String
    var category: Category
    var caption: String
    var seed: Int
    var imageURL: URL? = nil
    var isPinned: Bool = false
    var likes: Int = 0
}

struct Review: Identifiable, Hashable, Codable {
    let id: String
    var clientFirstName: String
    var rating: Int
    var text: String
    var date: Date
    var serviceName: String
    var proReply: String? = nil
    var photoSeed: Int? = nil
}
