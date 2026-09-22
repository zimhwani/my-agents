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

    var displayName: String { "\(firstName) \(lastInitial)." }
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
