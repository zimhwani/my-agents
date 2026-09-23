import Foundation
import CoreLocation

// Rows as PostgREST sends them. Keys arrive in snake_case and are converted to camelCase by
// `SupabaseJSON.decoder`, so `pro_id` is `proId` here, not `proID`. Enums are read as strings and
// mapped by hand, so one unexpected value can't sink a whole list.

struct DBID: Decodable { let id: String }

struct DBProCard: Decodable {
    let id: String
    let firstName: String?
    let lastInitial: String?
    let seed: Int?
    let specialties: [String]?
    let headline: String?
    let bio: String?
    let suburb: String?
    let approxLat: Double?
    let approxLng: Double?
    let travelRadiusKm: Double?
    let travelFeeCents: Int?
    let instantBook: Bool?
    let yearsExperience: Int?
    let responseMinutes: Int?
    let isVerified: Bool?
    let rating: Double?
    let reviewCount: Int?
    let completedBookings: Int?
    let isReliable: Bool?
    let bufferMinutes: Int?
    let stepMinutes: Int?
}

/// A pro's own row, read by her. The exact location is hers to see.
struct DBOwnPro: Decodable {
    let id: String
    let lastInitial: String?
    let specialties: [String]?
    let headline: String?
    let bio: String?
    let suburb: String?
    let lat: Double?
    let lng: Double?
    let travelRadiusKm: Double?
    let travelFeeCents: Int?
    let instantBook: Bool?
    let yearsExperience: Int?
    let responseMinutes: Int?
    let isVerified: Bool?
    let abn: String?
    let isActive: Bool?
    let bufferMinutes: Int?
    let stepMinutes: Int?
    let payoutsConnected: Bool?
    let rating: Double?
    let reviewCount: Int?
    let completedBookings: Int?
    let reliabilityScore: Int?
    let createdAt: Date?

    static let columns = "id,last_initial,specialties,headline,bio,suburb,lat,lng,travel_radius_km,travel_fee_cents,instant_book,years_experience,response_minutes,is_verified,abn,is_active,buffer_minutes,step_minutes,payouts_connected,rating,review_count,completed_bookings,reliability_score,created_at"
}

struct DBService: Decodable {
    let id: String
    let proId: String
    let name: String
    let category: String
    let priceCents: Int
    let minutes: Int
    let detail: String?
    let isPopular: Bool?
    let sortOrder: Int?

    static let columns = "id,pro_id,name,category,price_cents,minutes,detail,is_popular,sort_order"
}

struct DBWork: Decodable {
    let id: String
    let proId: String
    let category: String
    let caption: String?
    let imagePath: String?
    let seed: Int?
    let isPinned: Bool?
    let likes: Int?
    let sortOrder: Int?

    static let columns = "id,pro_id,category,caption,image_path,seed,is_pinned,likes,sort_order"
}

struct DBHours: Decodable {
    let proId: String
    let weekday: Int
    let startMinutes: Int
    let endMinutes: Int
}

struct DBDayOff: Decodable {
    let proId: String
    let day: String
}

struct DBProReview: Decodable {
    let id: String
    let rating: Int
    let text: String?
    let serviceName: String?
    let firstName: String?
    let proReply: String?
    let createdAt: Date?
}

struct DBProfile: Decodable {
    let id: String
    let firstName: String?
    let lastName: String?
    let seed: Int?
    let notificationsOn: Bool?
    let createdAt: Date?
}

struct DBContact: Decodable {
    let phone: String?
    let email: String?
}

struct DBAddress: Decodable {
    let id: String
    let label: String?
    let line1: String?
    let suburb: String?
    let state: String?
    let postcode: String?
    let lat: Double?
    let lng: Double?
    let instructions: String?

    static let columns = "id,label,line1,suburb,state,postcode,lat,lng,instructions"
}

struct DBCard: Decodable {
    let id: String
    let brand: String?
    let last4: String?
    let expiry: String?
    let isDefault: Bool?
}

struct DBFavourite: Decodable { let proId: String }
struct DBBlock: Decodable { let blockedId: String }

struct DBSlot: Decodable {
    let startsAt: Date
    let isAvailable: Bool
    let reason: String?
}

struct DBBookingService: Decodable {
    let serviceId: String?
    let name: String
    let category: String
    let priceCents: Int
    let minutes: Int
    let sortOrder: Int?
}

struct DBBookingEvent: Decodable {
    let id: String
    let status: String
    let at: Date
}

struct DBReview: Decodable {
    let id: String
    let rating: Int
    let text: String?
    let serviceName: String?
    let proReply: String?
    let createdAt: Date?
}

struct DBBooking: Decodable {
    let id: String
    let reference: String?
    let proId: String?
    let clientId: String?
    let status: String
    let startsAt: Date
    let createdAt: Date?
    let addressLabel: String?
    let addressLine1: String?
    let addressSuburb: String?
    let addressState: String?
    let addressPostcode: String?
    let addressInstructions: String?
    let notes: String?
    let servicesCents: Int?
    let travelFeeCents: Int?
    let bookingFeeCents: Int?
    let tipCents: Int?
    let discountCents: Int?
    let cancellationChargeCents: Int?
    let declineReason: String?
    let paymentMethodId: String?
    let holdState: String?
    let bookingServices: [DBBookingService]?
    let bookingEvents: [DBBookingEvent]?
    let reviews: OneOrMany<DBReview>?

    /// Every column we read, plus the embeds. Leaves out the geography and Stripe ids.
    static let select = "id,reference,pro_id,client_id,status,starts_at,created_at,address_label,address_line1,address_suburb,address_state,address_postcode,address_instructions,notes,services_cents,travel_fee_cents,booking_fee_cents,tip_cents,discount_cents,cancellation_charge_cents,decline_reason,payment_method_id,hold_state,booking_services(service_id,name,category,price_cents,minutes,sort_order),booking_events(id,status,at),reviews(id,rating,text,service_name,pro_reply,created_at)"

    /// Started but never paid for: checkout was left. The server lets these lapse.
    var isUnpaidRequest: Bool {
        (status == "requested" && (holdState ?? "none") == "none")
            || (status == "declined" && declineReason == "Payment not finished")
    }
}

struct DBMessage: Decodable {
    let id: String
    let threadId: String
    let senderId: String?
    let text: String
    let sentAt: Date
}

struct DBThread: Decodable {
    let id: String
    let bookingId: String
    let proId: String?
    let clientId: String?
    let clientReadAt: Date?
    let proReadAt: Date?
    let messages: [DBMessage]?

    static let select = "id,booking_id,pro_id,client_id,last_message_at,client_read_at,pro_read_at,messages(id,thread_id,sender_id,text,sent_at)"
}

struct DBPayoutItem: Decodable { let bookingId: String }

struct DBPayout: Decodable {
    let id: String
    let amountCents: Int
    let status: String
    let arrivesOn: String?
    let createdAt: Date?
    let payoutItems: [DBPayoutItem]?
}

// MARK: - Rows to models

enum DBMap {
    static func category(_ raw: String) -> Category { Category(rawValue: raw) ?? .hair }

    static func categories(_ raw: [String]?) -> [Category] { (raw ?? []).compactMap { Category(rawValue: $0) } }

    static func status(_ raw: String) -> BookingStatus { BookingStatus(rawValue: raw) ?? .requested }

    static func service(_ r: DBService) -> Service {
        Service(id: r.id, name: r.name, category: category(r.category), priceCents: r.priceCents, minutes: r.minutes,
                detail: r.detail ?? "", isPopular: r.isPopular ?? false)
    }

    static func work(_ r: DBWork, publicURL: (String) -> URL) -> WorkItem {
        var url: URL? = nil
        if let path = r.imagePath, !path.isEmpty { url = publicURL(path) }
        return WorkItem(id: r.id, category: category(r.category), caption: r.caption ?? "", seed: r.seed ?? 0,
                        imageURL: url, isPinned: r.isPinned ?? false, likes: r.likes ?? 0)
    }

    /// Postgres weekdays are 0 = Sunday; the app's are 1 = Sunday.
    static func availability(_ hours: [DBHours], daysOff: [DBDayOff], buffer: Int, step: Int) -> WeeklyAvailability {
        var byDay: [Weekday: [TimeRange]] = [:]
        for h in hours.sorted(by: { $0.startMinutes < $1.startMinutes }) {
            guard let day = Weekday(rawValue: h.weekday + 1) else { continue }
            byDay[day, default: []].append(TimeRange(startMinutes: h.startMinutes, endMinutes: h.endMinutes))
        }
        let off = daysOff.compactMap { SupabaseJSON.day(from: $0.day) }.sorted()
        return WeeklyAvailability(hours: byDay, daysOff: off, bufferMinutes: buffer, stepMinutes: step)
    }

    static func review(_ r: DBProReview) -> Review {
        Review(id: r.id, clientFirstName: r.firstName ?? "Client", rating: r.rating, text: r.text ?? "",
               date: r.createdAt ?? Date(), serviceName: r.serviceName ?? "", proReply: r.proReply)
    }

    static func pro(card c: DBProCard, services: [Service], work: [WorkItem], availability: WeeklyAvailability, reviews: [Review]) -> Pro {
        let specialties = categories(c.specialties)
        return Pro(
            id: c.id,
            firstName: c.firstName ?? "",
            lastInitial: c.lastInitial ?? "",
            specialties: specialties.isEmpty ? [.hair] : specialties,
            headline: c.headline ?? "",
            bio: c.bio ?? "",
            suburb: c.suburb ?? "",
            latitude: c.approxLat ?? 0,
            longitude: c.approxLng ?? 0,
            travelRadiusKm: c.travelRadiusKm ?? 8,
            travelFeeCents: c.travelFeeCents ?? 0,
            rating: c.rating ?? 0,
            reviewCount: c.reviewCount ?? 0,
            isVerified: c.isVerified ?? false,
            instantBook: c.instantBook ?? false,
            yearsExperience: c.yearsExperience ?? 0,
            responseMinutes: c.responseMinutes ?? 60,
            joined: Date(),
            services: services,
            work: work,
            reviews: reviews,
            availability: availability,
            seed: c.seed ?? c.id.hdSeed,
            isActive: true,
            completedBookings: c.completedBookings ?? 0,
            reliabilityScore: (c.isReliable ?? true) ? 1.0 : 0.9
        )
    }

    static func ownPro(_ r: DBOwnPro, firstName: String, seed: Int, services: [Service], work: [WorkItem],
                       availability: WeeklyAvailability, reviews: [Review]) -> Pro {
        let specialties = categories(r.specialties)
        return Pro(
            id: r.id,
            firstName: firstName,
            lastInitial: r.lastInitial ?? "",
            specialties: specialties.isEmpty ? [.hair] : specialties,
            headline: r.headline ?? "",
            bio: r.bio ?? "",
            suburb: r.suburb ?? "",
            latitude: r.lat ?? 0,
            longitude: r.lng ?? 0,
            travelRadiusKm: r.travelRadiusKm ?? 8,
            travelFeeCents: r.travelFeeCents ?? 0,
            rating: r.rating ?? 0,
            reviewCount: r.reviewCount ?? 0,
            isVerified: r.isVerified ?? false,
            instantBook: r.instantBook ?? false,
            yearsExperience: r.yearsExperience ?? 0,
            responseMinutes: r.responseMinutes ?? 60,
            joined: r.createdAt ?? Date(),
            services: services,
            work: work,
            reviews: reviews,
            availability: availability,
            seed: seed,
            isActive: r.isActive ?? true,
            completedBookings: r.completedBookings ?? 0,
            reliabilityScore: Double(r.reliabilityScore ?? 100) / 100,
            abn: r.abn ?? "",
            payoutsConnected: r.payoutsConnected ?? false
        )
    }

    static func address(_ r: DBAddress) -> Address {
        Address(id: r.id, label: r.label ?? "Home", line1: r.line1 ?? "", suburb: r.suburb ?? "", state: r.state ?? "VIC",
                postcode: r.postcode ?? "", latitude: r.lat ?? 0, longitude: r.lng ?? 0, instructions: r.instructions ?? "")
    }

    /// Stripe names brands in lowercase ("visa"); a card added through Apple Pay is saved as "Apple Pay".
    static func card(_ r: DBCard) -> PaymentMethod {
        let brand = r.brand ?? "Card"
        let isApplePay = brand == "Apple Pay"
        return PaymentMethod(id: r.id, kind: isApplePay ? .applePay : .card, brand: isApplePay ? brand : brand.capitalized,
                             last4: r.last4 ?? "", expiry: r.expiry ?? "", isDefault: r.isDefault ?? false)
    }

    /// `reviewer` is the client's first name, for the review on it.
    static func booking(_ r: DBBooking, coordinate: CLLocationCoordinate2D?, reviewer: String) -> Booking {
        let lines = (r.bookingServices ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
        let services = lines.enumerated().map { i, s in
            Service(id: s.serviceId ?? "\(r.id)_\(i)", name: s.name, category: category(s.category),
                    priceCents: s.priceCents, minutes: s.minutes, detail: "")
        }
        let events = (r.bookingEvents ?? []).sorted { $0.at < $1.at }.map {
            StatusEvent(id: $0.id, status: status($0.status), at: $0.at)
        }
        let address = Address(
            id: "addr_\(r.id)",
            label: r.addressLabel ?? "",
            line1: r.addressLine1 ?? "",
            suburb: r.addressSuburb ?? "",
            state: r.addressState ?? "VIC",
            postcode: r.addressPostcode ?? "",
            latitude: coordinate?.latitude ?? 0,
            longitude: coordinate?.longitude ?? 0,
            instructions: r.addressInstructions ?? ""
        )
        let current = status(r.status)
        var price = PriceBreakdown(
            servicesCents: r.servicesCents ?? 0,
            travelFeeCents: r.travelFeeCents ?? 0,
            bookingFeeCents: r.bookingFeeCents ?? Fees.bookingFeeCents,
            tipCents: r.tipCents ?? 0,
            discountCents: r.discountCents ?? 0
        )
        // A client cancel keeps only what she was charged, as the app has always shown it.
        if current == .cancelledByClient {
            price = PriceBreakdown(servicesCents: r.cancellationChargeCents ?? 0, travelFeeCents: 0, bookingFeeCents: 0)
        }
        var review: Review? = nil
        if let first = r.reviews?.items.first {
            review = Review(id: first.id, clientFirstName: reviewer, rating: first.rating, text: first.text ?? "",
                            date: first.createdAt ?? Date(), serviceName: first.serviceName ?? "", proReply: first.proReply)
        }
        return Booking(
            id: r.id,
            proID: r.proId ?? "",
            clientID: r.clientId ?? "",
            services: services,
            start: r.startsAt,
            address: address,
            notes: r.notes ?? "",
            inspoSeeds: [],
            status: current,
            price: price,
            createdAt: r.createdAt ?? r.startsAt,
            events: events,
            review: review,
            declineReason: r.declineReason,
            paymentMethodID: r.paymentMethodId,
            reference: r.reference ?? ""
        )
    }

    static func thread(_ r: DBThread) -> MessageThread {
        let clientID = r.clientId ?? ""
        let proID = r.proId ?? ""
        let messages = (r.messages ?? []).sorted { $0.sentAt < $1.sentAt }.map { m in
            Message(id: m.id, threadID: m.threadId, senderID: m.senderId ?? "system", text: m.text, sentAt: m.sentAt,
                    isSystem: m.senderId == nil)
        }
        let forClient = messages.filter { $0.senderID != clientID && $0.sentAt > (r.clientReadAt ?? .distantPast) }.count
        let forPro = messages.filter { $0.senderID != proID && $0.sentAt > (r.proReadAt ?? .distantPast) }.count
        return MessageThread(id: r.id, bookingID: r.bookingId, proID: proID, clientID: clientID, messages: messages,
                             unreadForClient: forClient, unreadForPro: forPro)
    }

    static func payout(_ r: DBPayout) -> Payout {
        let date = r.arrivesOn.flatMap { SupabaseJSON.day(from: $0) } ?? r.createdAt ?? Date()
        return Payout(id: r.id, amountCents: r.amountCents, date: date, status: r.status == "paid" ? .paid : .pending,
                      bookingIDs: (r.payoutItems ?? []).map(\.bookingId))
    }
}
