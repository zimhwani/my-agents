import Foundation
import CoreLocation

/// The real backend: the Supabase project in `supabase/`, over plain HTTPS (`SupabaseAPI`).
/// Row-level security decides what each call may see; prices, slots and status moves are checked
/// on the server, so this side only asks.
final class SupabaseDataService: DataService {
    let api: SupabaseAPI

    private let lock = NSLock()
    /// The client as last loaded or saved, so a save only sends what changed.
    private var _synced: Client? = nil
    /// Places we've already looked up, by their written address.
    private var _places: [String: CLLocationCoordinate2D] = [:]

    init(api: SupabaseAPI) {
        self.api = api
    }

    private var synced: Client? {
        get { lock.lock(); defer { lock.unlock() }; return _synced }
        set { lock.lock(); _synced = newValue; lock.unlock() }
    }

    private func place(_ key: String) -> CLLocationCoordinate2D? {
        lock.lock(); defer { lock.unlock() }
        return _places[key]
    }

    private func remember(_ key: String, _ coordinate: CLLocationCoordinate2D) {
        lock.lock(); _places[key] = coordinate; lock.unlock()
    }

    // MARK: Plumbing

    private func q(_ name: String, _ value: String) -> URLQueryItem { URLQueryItem(name: name, value: value) }

    private func inList(_ ids: [String]) -> String { "in.(" + ids.joined(separator: ",") + ")" }

    private func me() async throws -> String {
        guard let id = await api.userID else { throw DataError.notSignedIn }
        return id
    }

    private func get<T: Decodable>(_ type: T.Type, _ table: String, _ query: [URLQueryItem]) async throws -> T {
        do {
            let data = try await api.call("GET", "rest/v1/\(table)", query: query)
            return try SupabaseJSON.decode(type, from: data)
        } catch {
            throw Self.translate(error)
        }
    }

    private func rpc<T: Decodable>(_ type: T.Type, _ name: String, _ args: [String: Any], query: [URLQueryItem] = []) async throws -> T {
        do {
            let data = try await api.call("POST", "rest/v1/rpc/\(name)", query: query, body: try SupabaseJSON.body(args))
            return try SupabaseJSON.decode(type, from: data)
        } catch {
            throw Self.translate(error)
        }
    }

    /// Insert, update or delete, with nothing wanted back.
    private func write(_ method: String, _ table: String, query: [URLQueryItem] = [], body: Any? = nil, prefer: String? = nil) async throws {
        do {
            let data: Data? = try body.map { try SupabaseJSON.body($0) }
            _ = try await api.call(method, "rest/v1/\(table)", query: query, body: data, prefer: prefer ?? "return=minimal")
        } catch {
            throw Self.translate(error)
        }
    }

    /// PATCH that says how many rows it touched, so the caller knows whether to insert instead.
    private func patchCount(_ table: String, query: [URLQueryItem], body: Any) async throws -> Int {
        do {
            let data = try await api.call("PATCH", "rest/v1/\(table)", query: query + [q("select", "*")],
                                          body: try SupabaseJSON.body(body), prefer: "return=representation")
            let rows = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [Any]
            return rows?.count ?? 0
        } catch {
            throw Self.translate(error)
        }
    }

    /// An RPC that returns nothing (PostgREST sends an empty body or `null`).
    private func rpcVoid(_ name: String, _ args: [String: Any]) async throws {
        do {
            _ = try await api.call("POST", "rest/v1/rpc/\(name)", body: try SupabaseJSON.body(args))
        } catch {
            throw Self.translate(error)
        }
    }

    private func callFunction(_ name: String, body: [String: Any]) async throws -> Data {
        try await api.call("POST", "functions/v1/\(name)", body: try SupabaseJSON.body(body))
    }

    /// Server words to the app's own errors and copy.
    static func translate(_ error: Error) -> Error {
        guard let f = error as? SupabaseFailure else { return error }
        if f.says("slot_taken") { return DataError.slotTaken }
        if f.says("outside_travel_area") { return DataError.outsideTravelArea }
        if f.says("bad_services") { return DataError.servicesChanged }
        if f.says("own_booking") { return DataError.ownBooking }
        if f.says("pro_not_found") || f.says("blocked") || f.says("address_not_found") || f.says("not_found") { return DataError.notFound }
        if f.says("bad_transition") || f.says("forbidden") { return DataError.alreadyMoved }
        if f.says("live_booking") { return DataError.liveBooking }
        if f.says("not_signed_in") { return DataError.notSignedIn }
        if f.says("otp_expired") || f.says("invalid_credentials") || f.message.lowercased().contains("token has expired") {
            return DataError.wrongCode
        }
        if f.status == 429 || f.code.hasPrefix("over_") { return DataError.tooManyTries }
        if f.says("sms_send_failed") || f.says("phone_provider_disabled") || f.code == "validation_failed" { return DataError.codeNotSent }
        if f.status == 401 { return DataError.notSignedIn }
        if f.status >= 500 { return DataError.server }
        return DataError.network
    }

    static func isUUID(_ id: String) -> Bool { UUID(uuidString: id) != nil }

    /// "0412 345 678" → "+61412345678".
    static func e164(_ phone: String) -> String {
        let digits = phone.filter(\.isNumber)
        if digits.hasPrefix("61") && digits.count == 11 { return "+" + digits }
        if digits.hasPrefix("0") { return "+61" + String(digits.dropFirst()) }
        return "+61" + digits
    }

    /// "61412345678" (as GoTrue keeps it) → "0412 345 678".
    static func localPhone(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty else { return "" }
        if digits.hasPrefix("61") && digits.count == 11 { return AUPhone.display("0" + String(digits.dropFirst(2))) }
        return AUPhone.display(digits)
    }

    private static func point(_ latitude: Double, _ longitude: Double) -> String {
        "SRID=4326;POINT(\(longitude) \(latitude))"
    }

    // MARK: Session

    func sendCode(phone: String) async throws {
        do { try await api.sendCode(phone: Self.e164(phone)) } catch { throw Self.translate(error) }
    }

    func verifyCode(phone: String, code: String) async throws -> Client {
        let session: SupabaseSession
        do { session = try await api.verifyCode(phone: Self.e164(phone), code: code) } catch { throw Self.translate(error) }
        return try await loadClient(session)
    }

    func signInWithApple(_ credential: AppleCredential) async throws -> Client {
        let session: SupabaseSession
        do {
            session = try await api.signIn(provider: "apple", idToken: credential.idToken, nonce: credential.rawNonce)
        } catch {
            throw Self.translate(error)
        }
        var client = try await loadClient(session)
        // Apple only gives the name the first time, so it's kept straight away.
        if synced == nil {
            if client.firstName.isEmpty { client.firstName = credential.firstName }
            if client.lastName.isEmpty { client.lastName = credential.lastName }
            if client.email.isEmpty { client.email = credential.email }
            if !client.firstName.isEmpty { try? await updateClient(client) }
        }
        return client
    }

    func currentClient() async -> Client? {
        guard let session = await api.currentSession else { return nil }
        let first = try? await loadClient(session)
        if first != nil { return first }
        // One more go, in case the network was waking up.
        try? await Task.sleep(for: .seconds(1))
        guard let again = await api.currentSession else { return nil }
        return try? await loadClient(again)
    }

    /// Everything the You tab shows. A brand-new account has no profile yet; it's made on first save.
    private func loadClient(_ session: SupabaseSession) async throws -> Client {
        let id = session.userID
        async let profiles = get([DBProfile].self, "profiles",
                                 [q("id", "eq.\(id)"), q("select", "id,first_name,last_name,seed,notifications_on,created_at")])
        async let contacts = get([DBContact].self, "profile_contacts", [q("profile_id", "eq.\(id)"), q("select", "phone,email")])
        async let addresses = get([DBAddress].self, "addresses",
                                  [q("profile_id", "eq.\(id)"), q("select", DBAddress.columns), q("order", "created_at.asc")])
        async let cards = get([DBCard].self, "payment_methods",
                              [q("profile_id", "eq.\(id)"), q("select", "id,brand,last4,expiry,is_default"), q("order", "created_at.asc")])
        async let favourites = get([DBFavourite].self, "favourites", [q("client_id", "eq.\(id)"), q("select", "pro_id")])

        let profile = try await profiles.first
        let contact = try await contacts.first
        let savedPhone = contact?.phone ?? ""
        let savedEmail = contact?.email ?? ""
        let client = Client(
            id: id,
            firstName: profile?.firstName ?? "",
            lastName: profile?.lastName ?? "",
            phone: Self.localPhone(savedPhone.isEmpty ? session.phone : savedPhone),
            email: savedEmail.isEmpty ? session.email : savedEmail,
            addresses: try await addresses.map(DBMap.address),
            paymentMethods: try await cards.map(DBMap.card),
            favouriteProIDs: Set(try await favourites.map(\.proId)),
            seed: profile?.seed ?? id.hdSeed,
            notificationsOn: profile?.notificationsOn ?? true,
            joined: profile?.createdAt ?? Date()
        )
        synced = profile == nil ? nil : client
        return client
    }

    func currentPro() async -> Pro? {
        guard let id = await api.userID else { return nil }
        return try? await loadOwnPro(id)
    }

    private func loadOwnPro(_ id: String) async throws -> Pro? {
        let rows = try await get([DBOwnPro].self, "pros", [q("id", "eq.\(id)"), q("select", DBOwnPro.columns)])
        guard let row = rows.first else { return nil }
        async let parts = hydrate(ids: [id])
        async let reviews = rpc([DBProReview].self, "pro_reviews", ["p": id, "limit_n": 50])
        var name = synced?.firstName ?? ""
        var seed = synced?.seed ?? id.hdSeed
        if name.isEmpty {
            let profile = try? await get([DBProfile].self, "profiles", [q("id", "eq.\(id)"), q("select", "id,first_name,seed")]).first
            name = profile?.firstName ?? ""
            seed = profile?.seed ?? seed
        }
        let p = try await parts
        let availability = DBMap.availability(p.hours[id] ?? [], daysOff: p.daysOff[id] ?? [],
                                              buffer: row.bufferMinutes ?? 30, step: row.stepMinutes ?? 30)
        return DBMap.ownPro(row, firstName: name, seed: seed, services: p.services[id] ?? [], work: p.work[id] ?? [],
                            availability: availability, reviews: try await reviews.map(DBMap.review))
    }

    func updateClient(_ client: Client) async throws {
        let id = try await me()
        let before = synced

        // Profile first: everything else hangs off it.
        if before == nil || before?.firstName != client.firstName || before?.lastName != client.lastName
            || before?.notificationsOn != client.notificationsOn {
            let fields: [String: Any] = ["first_name": client.firstName, "last_name": client.lastName,
                                         "notifications_on": client.notificationsOn]
            if try await patchCount("profiles", query: [q("id", "eq.\(id)")], body: fields) == 0 {
                var insert = fields
                insert["id"] = id
                try await write("POST", "profiles", body: insert)
            }
        }

        if before == nil || before?.phone != client.phone || before?.email != client.email {
            let fields: [String: Any] = ["phone": client.phone, "email": client.email]
            if try await patchCount("profile_contacts", query: [q("profile_id", "eq.\(id)")], body: fields) == 0 {
                var insert = fields
                insert["profile_id"] = id
                try await write("POST", "profile_contacts", body: insert)
            }
        }

        // Addresses: add, change, remove. Only ids the server could hold are sent.
        let old = before?.addresses ?? []
        for a in client.addresses where Self.isUUID(a.id) {
            let fields: [String: Any] = [
                "label": a.label, "line1": a.line1, "suburb": a.suburb, "state": a.state, "postcode": a.postcode,
                "location": Self.point(a.latitude, a.longitude), "instructions": a.instructions
            ]
            if let was = old.first(where: { $0.id == a.id }) {
                if was != a { try await write("PATCH", "addresses", query: [q("id", "eq.\(a.id)")], body: fields) }
            } else {
                var insert = fields
                insert["id"] = a.id.lowercased()
                insert["profile_id"] = id
                try await write("POST", "addresses", body: insert, prefer: "return=minimal,resolution=ignore-duplicates")
            }
        }
        let keptAddresses = Set(client.addresses.map(\.id))
        let goneAddresses = old.map(\.id).filter { !keptAddresses.contains($0) && Self.isUUID($0) }
        if !goneAddresses.isEmpty { try await write("DELETE", "addresses", query: [q("id", inList(goneAddresses))]) }

        // Cards: the server adds them (after Stripe has one). Here they're removed or made the default.
        let oldCards = before?.paymentMethods ?? []
        let keptCards = Set(client.paymentMethods.map(\.id))
        let goneCards = oldCards.map(\.id).filter { !keptCards.contains($0) && Self.isUUID($0) }
        if !goneCards.isEmpty { try await write("DELETE", "payment_methods", query: [q("id", inList(goneCards))]) }
        if let chosen = client.paymentMethods.first(where: { $0.isDefault && $0.kind == .card }), Self.isUUID(chosen.id),
           oldCards.first(where: { $0.id == chosen.id })?.isDefault != true {
            try await write("PATCH", "payment_methods", query: [q("profile_id", "eq.\(id)"), q("id", "neq.\(chosen.id)")],
                            body: ["is_default": false])
            try await write("PATCH", "payment_methods", query: [q("id", "eq.\(chosen.id)")], body: ["is_default": true])
        }

        // Favourites.
        let oldFavourites = before?.favouriteProIDs ?? []
        for proID in client.favouriteProIDs.subtracting(oldFavourites) where Self.isUUID(proID) {
            try await write("POST", "favourites", body: ["client_id": id, "pro_id": proID],
                            prefer: "return=minimal,resolution=ignore-duplicates")
        }
        let unsaved = Array(oldFavourites.subtracting(client.favouriteProIDs)).filter(Self.isUUID)
        if !unsaved.isEmpty {
            try await write("DELETE", "favourites", query: [q("client_id", "eq.\(id)"), q("pro_id", inList(unsaved))])
        }

        synced = client
    }

    func updatePro(_ pro: Pro) async throws -> Pro {
        let id = try await me()
        var fields: [String: Any] = [
            "last_initial": pro.lastInitial,
            "specialties": pro.specialties.map(\.rawValue),
            "headline": pro.headline,
            "bio": pro.bio,
            "suburb": pro.suburb,
            "location": Self.point(pro.latitude, pro.longitude),
            "travel_radius_km": min(50, max(1, pro.travelRadiusKm)),
            "travel_fee_cents": max(0, pro.travelFeeCents),
            "instant_book": pro.instantBook,
            "years_experience": pro.yearsExperience,
            "buffer_minutes": pro.availability.bufferMinutes,
            "step_minutes": pro.availability.stepMinutes
        ]
        if pro.abn.isEmpty {
            fields["abn"] = NSNull()
        } else {
            fields["abn"] = pro.abn
        }
        var update = fields
        update["is_active"] = pro.isActive
        if try await patchCount("pros", query: [q("id", "eq.\(id)")], body: update) == 0 {
            var insert = fields
            insert["id"] = id
            try await write("POST", "pros", body: insert)
        }

        // Services: upsert what's there, delete what's gone. Ids made on the phone become uuids.
        let existingServices = try await get([DBID].self, "services", [q("pro_id", "eq.\(id)"), q("select", "id")]).map(\.id)
        var serviceRows: [[String: Any]] = []
        for (i, s) in pro.services.enumerated() {
            serviceRows.append([
                "id": Self.isUUID(s.id) ? s.id.lowercased() : UUID().uuidString.lowercased(),
                "pro_id": id, "name": s.name, "category": s.category.rawValue, "price_cents": s.priceCents,
                "minutes": s.minutes, "detail": s.detail, "is_popular": s.isPopular, "sort_order": i, "is_active": true
            ])
        }
        if !serviceRows.isEmpty {
            try await write("POST", "services", body: serviceRows, prefer: "return=minimal,resolution=merge-duplicates")
        }
        let keptServices = Set(serviceRows.compactMap { $0["id"] as? String })
        let goneServices = existingServices.filter { !keptServices.contains($0.lowercased()) }
        if !goneServices.isEmpty { try await write("DELETE", "services", query: [q("id", inList(goneServices))]) }

        // Work: same. Photos themselves aren't uploaded yet; the tiles keep their placeholder art.
        let existingWork = try await get([DBID].self, "work_items", [q("pro_id", "eq.\(id)"), q("select", "id")]).map(\.id)
        var workRows: [[String: Any]] = []
        for (i, w) in pro.work.enumerated() {
            workRows.append([
                "id": Self.isUUID(w.id) ? w.id.lowercased() : UUID().uuidString.lowercased(),
                "pro_id": id, "category": w.category.rawValue, "caption": w.caption, "seed": w.seed,
                "is_pinned": w.isPinned, "sort_order": i
            ])
        }
        if !workRows.isEmpty {
            try await write("POST", "work_items", body: workRows, prefer: "return=minimal,resolution=merge-duplicates")
        }
        let keptWork = Set(workRows.compactMap { $0["id"] as? String })
        let goneWork = existingWork.filter { !keptWork.contains($0.lowercased()) }
        if !goneWork.isEmpty { try await write("DELETE", "work_items", query: [q("id", inList(goneWork))]) }

        // Hours and days off: replaced whole. Postgres weekdays are 0 = Sunday.
        try await write("DELETE", "availability", query: [q("pro_id", "eq.\(id)")])
        var hourRows: [[String: Any]] = []
        for (day, ranges) in pro.availability.hours {
            for r in ranges where r.endMinutes > r.startMinutes {
                hourRows.append(["pro_id": id, "weekday": day.rawValue - 1, "start_minutes": r.startMinutes, "end_minutes": r.endMinutes])
            }
        }
        if !hourRows.isEmpty { try await write("POST", "availability", body: hourRows) }

        try await write("DELETE", "days_off", query: [q("pro_id", "eq.\(id)")])
        var offRows: [[String: Any]] = []
        let offDays: Set<String> = Set(pro.availability.daysOff.map { SupabaseJSON.day($0) })
        for day in offDays {
            offRows.append(["pro_id": id, "day": day])
        }
        if !offRows.isEmpty { try await write("POST", "days_off", body: offRows) }

        return try await loadOwnPro(id) ?? pro
    }

    func signOut() async {
        await api.signOut()
        synced = nil
    }

    func deleteAccount() async throws {
        try await rpcVoid("delete_my_account", [:])
        await api.forget()
        synced = nil
    }

    // MARK: Discovery

    private struct Parts {
        var services: [String: [Service]] = [:]
        var work: [String: [WorkItem]] = [:]
        var hours: [String: [DBHours]] = [:]
        var daysOff: [String: [DBDayOff]] = [:]
    }

    /// Services, work, hours and days off for a set of pros, four calls in all.
    private func hydrate(ids: [String]) async throws -> Parts {
        guard !ids.isEmpty else { return Parts() }
        let list = inList(ids)
        async let services = get([DBService].self, "services",
                                 [q("pro_id", list), q("is_active", "eq.true"), q("select", DBService.columns), q("order", "sort_order.asc")])
        async let work = get([DBWork].self, "work_items",
                             [q("pro_id", list), q("select", DBWork.columns), q("order", "sort_order.asc")])
        async let hours = get([DBHours].self, "availability",
                              [q("pro_id", list), q("select", "pro_id,weekday,start_minutes,end_minutes")])
        async let off = get([DBDayOff].self, "days_off",
                            [q("pro_id", list), q("day", "gte.\(SupabaseJSON.day(Date()))"), q("select", "pro_id,day")])

        let serviceRows = try await services
        let workRows = try await work
        let hourRows = try await hours
        let offRows = try await off

        var parts = Parts()
        let api = self.api
        for s in serviceRows {
            parts.services[s.proId, default: []].append(DBMap.service(s))
        }
        for w in workRows {
            let item = DBMap.work(w, publicURL: { path in api.publicURL(bucket: "work", path: path) })
            parts.work[w.proId, default: []].append(item)
        }
        for h in hourRows {
            parts.hours[h.proId, default: []].append(h)
        }
        for d in offRows {
            parts.daysOff[d.proId, default: []].append(d)
        }
        return parts
    }

    private func pros(from cards: [DBProCard], reviews: [String: [Review]] = [:]) async throws -> [Pro] {
        let parts = try await hydrate(ids: cards.map(\.id))
        return cards.map { c in
            let availability = DBMap.availability(parts.hours[c.id] ?? [], daysOff: parts.daysOff[c.id] ?? [],
                                                  buffer: c.bufferMinutes ?? 30, step: c.stepMinutes ?? 30)
            return DBMap.pro(card: c, services: parts.services[c.id] ?? [], work: parts.work[c.id] ?? [],
                             availability: availability, reviews: reviews[c.id] ?? [])
        }
    }

    func pros(near coordinate: CLLocationCoordinate2D, category: Category?) async throws -> [Pro] {
        var args: [String: Any] = ["lat": coordinate.latitude, "lng": coordinate.longitude, "limit_n": 50]
        if let category { args["cat"] = category.rawValue }
        let cards = try await rpc([DBProCard].self, "pros_near", args)
        return try await pros(from: cards)
    }

    func pro(id: String) async throws -> Pro? {
        guard Self.isUUID(id) else { return nil }
        async let cards = rpc([DBProCard].self, "pro_card", ["p": id])
        async let reviews = rpc([DBProReview].self, "pro_reviews", ["p": id, "limit_n": 50])
        guard let card = try await cards.first else { return nil }
        let list = try await reviews.map(DBMap.review)
        return try await pros(from: [card], reviews: [id: list]).first
    }

    func proCards(ids: [String]) async throws -> [Pro] {
        let wanted = ids.filter(Self.isUUID)
        guard !wanted.isEmpty, await api.userID != nil else { return [] }
        let cards = try await rpc([DBProCard].self, "pro_cards", ["ids": wanted])
        return try await pros(from: cards)
    }

    func slots(for pro: Pro, on day: Date, minutes: Int) async throws -> [TimeSlot] {
        let rows = try await rpc([DBSlot].self, "pro_slots",
                                 ["p": pro.id, "day": SupabaseJSON.day(day), "duration_minutes": minutes])
        return rows.map { TimeSlot(start: $0.startsAt, isAvailable: $0.isAvailable, reason: $0.reason) }
    }

    func clientNames(ids: [String]) async throws -> [String: String] {
        let wanted = Array(Set(ids.filter(Self.isUUID)))
        guard !wanted.isEmpty else { return [:] }
        let rows = try await get([DBProfile].self, "profiles", [q("id", inList(wanted)), q("select", "id,first_name")])
        var out: [String: String] = [:]
        for r in rows { out[r.id] = r.firstName ?? "" }
        return out
    }

    // MARK: Bookings

    func bookings(clientID: String) async throws -> [Booking] {
        let id = try await me()
        let rows = try await get([DBBooking].self, "bookings",
                                 [q("client_id", "eq.\(id)"), q("select", DBBooking.select), q("order", "starts_at.desc")])
        return await toBookings(rows.filter { !$0.isUnpaidRequest }, forPro: false)
    }

    func bookings(proID: String) async throws -> [Booking] {
        let rows = try await rpc([DBBooking].self, "bookings_for_pro", [:], query: [q("select", DBBooking.select)])
        return await toBookings(rows, forPro: true)
    }

    func booking(id: String) async throws -> Booking? {
        guard Self.isUUID(id) else { return nil }
        let mine = try await get([DBBooking].self, "bookings", [q("id", "eq.\(id)"), q("select", DBBooking.select)])
        if let row = mine.first { return await toBookings([row], forPro: false).first }
        let hers = try await rpc([DBBooking].self, "bookings_for_pro", [:], query: [q("id", "eq.\(id)"), q("select", DBBooking.select)])
        if let row = hers.first { return await toBookings([row], forPro: true).first }
        return nil
    }

    /// Rows to bookings, with a name on any review and a map pin for the address.
    private func toBookings(_ rows: [DBBooking], forPro: Bool) async -> [Booking] {
        var names: [String: String] = [:]
        if forPro {
            names = (try? await clientNames(ids: rows.compactMap(\.clientId))) ?? [:]
        }
        let mine = synced
        var out: [Booking] = []
        var lookups = 0
        for r in rows {
            let reviewer = forPro ? (names[r.clientId ?? ""] ?? "Client") : (mine?.firstName ?? "You")
            let pin = await coordinate(for: r, saved: mine?.addresses ?? [], lookups: &lookups)
            out.append(DBMap.booking(r, coordinate: pin, reviewer: reviewer))
        }
        return out
    }

    /// Bookings keep the address as text. The pin comes from the matching saved address, or Apple's
    /// geocoder (remembered, and at most a few new lookups per load so it stays quick).
    private func coordinate(for r: DBBooking, saved: [Address], lookups: inout Int) async -> CLLocationCoordinate2D? {
        let line1 = r.addressLine1 ?? ""
        let suburb = r.addressSuburb ?? ""
        if let match = saved.first(where: { !line1.isEmpty && $0.line1 == line1 && $0.suburb == suburb }) {
            return CLLocationCoordinate2D(latitude: match.latitude, longitude: match.longitude)
        }
        let written = [line1, suburb, r.addressState ?? "VIC", r.addressPostcode ?? "", "Australia"]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        if let known = place(written) { return known }
        guard lookups < 6 else { return nil }
        lookups += 1
        guard let mark = try? await CLGeocoder().geocodeAddressString(written).first, let location = mark.location else { return nil }
        remember(written, location.coordinate)
        return location.coordinate
    }

    func createBooking(_ draft: BookingDraft) async throws -> Booking {
        guard let start = draft.start, let address = draft.address else { throw DataError.notFound }
        let id = try await me()

        // The server books from a saved address. A saved one goes as it is. Anything else (where you
        // are now, or a saved one with new door notes) is saved for this booking and taken out after:
        // the booking keeps its own copy.
        var addressID = address.id
        var temporary: String? = nil
        let saved = synced?.addresses.first { $0.id == address.id }
        if saved == nil || saved != address || !Self.isUUID(address.id) {
            let newID = UUID().uuidString.lowercased()
            let row: [String: Any] = [
                "id": newID, "profile_id": id, "label": address.label.isEmpty ? "Here" : address.label,
                "line1": address.line1, "suburb": address.suburb, "state": address.state, "postcode": address.postcode,
                "location": Self.point(address.latitude, address.longitude), "instructions": address.instructions
            ]
            try await write("POST", "addresses", body: row)
            addressID = newID
            temporary = newID
        }

        let args: [String: Any] = [
            "p_pro": draft.pro.id,
            "p_service_ids": draft.services.map(\.id),
            "p_starts_at": SupabaseJSON.string(from: start),
            "p_address_id": addressID,
            "p_notes": draft.notes
        ]
        let made: OneOrMany<DBBooking>
        do {
            made = try await rpc(OneOrMany<DBBooking>.self, "create_booking", args)
        } catch {
            if let temporary { try? await write("DELETE", "addresses", query: [q("id", "eq.\(temporary)")]) }
            throw error
        }
        if let temporary { try? await write("DELETE", "addresses", query: [q("id", "eq.\(temporary)")]) }
        guard let row = made.items.first else { throw DataError.server }
        let full = try? await booking(id: row.id)
        if let full { return full }
        let mapped = await toBookings([row], forPro: false)
        return mapped.first ?? DBMap.booking(row, coordinate: nil, reviewer: "You")
    }

    /// Nothing to do: the server lets an unpaid booking lapse after 30 minutes.
    func abandonBooking(id: String) async {}

    func updateStatus(bookingID: String, to status: BookingStatus, reason: String?) async throws -> Booking {
        var args: [String: Any] = ["b_id": bookingID, "new_status": status.rawValue]
        if let reason { args["reason"] = reason }
        let moved = try await rpc(OneOrMany<DBBooking>.self, "move_booking", args)
        let full = try await booking(id: bookingID)
        if let full { return full }
        guard let row = moved.items.first else { throw DataError.notFound }
        return DBMap.booking(row, coordinate: nil, reviewer: "You")
    }

    /// There's no way to move a booking's time on the server yet.
    func reschedule(bookingID: String, to start: Date) async throws -> Booking {
        throw DataError.cantReschedule
    }

    func submitReview(bookingID: String, rating: Int, text: String, tipCents: Int) async throws -> Booking {
        let id = try await me()
        guard var current = try await booking(id: bookingID) else { throw DataError.notFound }
        if current.status == .done {
            // "Pay" on a done booking: the hold is charged, and the tip goes as its own charge.
            let pay: [String: Any] = ["booking_id": bookingID, "tip_cents": max(0, tipCents)]
            do {
                _ = try await callFunction("pay-booking", body: pay)
            } catch let failure as SupabaseFailure {
                throw failure.status == 401 ? DataError.notSignedIn : DataError.payFailed
            }
            current = try await booking(id: bookingID) ?? current
        }
        if current.review == nil {
            let review: [String: Any] = [
                "booking_id": bookingID, "pro_id": current.proID, "client_id": id, "rating": rating,
                "text": text, "service_name": current.services.first?.name ?? ""
            ]
            try await write("POST", "reviews", body: review)
        }
        return try await booking(id: bookingID) ?? current
    }

    func flagBooking(bookingID: String, detail: String) async throws -> Booking {
        _ = try await rpc(OneOrMany<DBBooking>.self, "flag_booking", ["b_id": bookingID, "detail": detail])
        guard let fresh = try await booking(id: bookingID) else { throw DataError.notFound }
        return fresh
    }

    // MARK: Messaging

    func threads(userID: String) async throws -> [MessageThread] {
        let rows = try await get([DBThread].self, "threads",
                                 [q("select", DBThread.select), q("order", "last_message_at.desc.nullslast"),
                                  q("messages.order", "sent_at.asc")])
        return rows.map(DBMap.thread)
    }

    func thread(id: String) async throws -> MessageThread? {
        guard Self.isUUID(id) else { return nil }
        let rows = try await get([DBThread].self, "threads",
                                 [q("id", "eq.\(id)"), q("select", DBThread.select), q("messages.order", "sent_at.asc")])
        return rows.first.map(DBMap.thread)
    }

    func send(text: String, threadID: String, senderID: String) async throws -> MessageThread {
        let id = try await me()
        try await write("POST", "messages", body: ["thread_id": threadID, "sender_id": id, "text": String(text.prefix(2000))])
        guard let fresh = try await thread(id: threadID) else { throw DataError.notFound }
        return fresh
    }

    func markRead(threadID: String, asPro: Bool) async {
        guard Self.isUUID(threadID) else { return }
        let column = asPro ? "pro_read_at" : "client_read_at"
        try? await write("PATCH", "threads", query: [q("id", "eq.\(threadID)")],
                         body: [column: SupabaseJSON.string(from: Date())])
    }

    // MARK: Safety

    func blockedIDs() async throws -> Set<String> {
        guard let id = await api.userID else { return [] }
        let rows = try await get([DBBlock].self, "blocks", [q("blocker_id", "eq.\(id)"), q("select", "blocked_id")])
        return Set(rows.map(\.blockedId))
    }

    func block(userID: String) async throws {
        let id = try await me()
        try await write("POST", "blocks", body: ["blocker_id": id, "blocked_id": userID],
                        prefer: "return=minimal,resolution=ignore-duplicates")
    }

    func report(userID: String, bookingID: String?, reason: String, detail: String) async throws {
        let id = try await me()
        var body: [String: Any] = ["reporter_id": id, "reported_id": userID, "reason": reason, "detail": detail]
        if let bookingID, Self.isUUID(bookingID) { body["booking_id"] = bookingID }
        try await write("POST", "reports", body: body)
    }

    // MARK: Pro side

    func payouts(proID: String) async throws -> [Payout] {
        let rows = try await get([DBPayout].self, "payouts",
                                 [q("select", "id,amount_cents,status,arrives_on,created_at,payout_items(booking_id)"),
                                  q("order", "created_at.desc")])
        return rows.map(DBMap.payout)
    }
}
