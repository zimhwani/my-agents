import Foundation

/// The signed-in user, as GoTrue hands it back. Kept in the Keychain between launches.
struct SupabaseSession: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userID: String
    var phone: String
    var email: String
}

/// A call that came back with an error status. `code` is the most specific word we got:
/// the text of a database `raise exception` (e.g. "slot_taken"), GoTrue's `error_code`, or an edge
/// function's `error`.
struct SupabaseFailure: Error {
    var status: Int
    var code: String
    var message: String

    /// True if any of the fields is exactly this word, however the server phrased it.
    func says(_ word: String) -> Bool { code == word || message == word }
}

/// JSON in and out, the way PostgREST writes it: snake_case keys, ISO-8601 times with or
/// without fractional seconds.
enum SupabaseJSON {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = SupabaseJSON.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a timestamp: \(raw)")
        }
        return decoder
    }()

    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let withoutFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// "2026-09-23T10:00:00+00:00" or "2026-09-23T10:00:00.123456+00:00". Fractions are cut to
    /// milliseconds first, which is all the formatter reliably takes.
    static func date(from raw: String) -> Date? {
        var s = raw.replacingOccurrences(of: " ", with: "T")
        guard let dot = s.firstIndex(of: ".") else { return withoutFraction.date(from: s) }
        var end = s.index(after: dot)
        while end < s.endIndex, s[end].isNumber { end = s.index(after: end) }
        var fraction = String(s[s.index(after: dot)..<end])
        if fraction.count > 3 { fraction = String(fraction.prefix(3)) }
        while fraction.count < 3 { fraction += "0" }
        s = String(s[..<dot]) + "." + fraction + String(s[end...])
        return withFraction.date(from: s) ?? withoutFraction.date(from: raw)
    }

    /// A timestamp for the server, in UTC.
    static func string(from date: Date) -> String { withoutFraction.string(from: date) }

    /// A calendar day, "2026-09-23", in the phone's time zone.
    static func day(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    /// "2026-09-23" back to the start of that day, in the phone's time zone.
    static func day(from raw: String) -> Date? {
        let parts = raw.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var c = DateComponents()
        c.year = parts[0]; c.month = parts[1]; c.day = parts[2]
        return Calendar.current.date(from: c)
    }

    static func body(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [])
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            #if DEBUG
            print("Supabase decode failed for \(type): \(error)")
            #endif
            throw DataError.network
        }
    }
}

/// Decodes a PostgREST embed that may come back as one object, an array, or null.
struct OneOrMany<T: Decodable>: Decodable {
    let items: [T]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            items = []
        } else if let many = try? container.decode([T].self) {
            items = many
        } else {
            items = [try container.decode(T.self)]
        }
    }
}

/// Talks to one Supabase project over plain HTTPS: PostgREST, GoTrue, Storage and edge functions.
/// Holds the session, refreshes it when it's about to run out (or on a 401, once), and keeps it in
/// the Keychain.
actor SupabaseAPI {
    let baseURL: URL
    let apiKey: String

    private var session: SupabaseSession?
    private var refreshing: Task<SupabaseSession, Error>?

    private static let keychainAccount = "supabase.session"

    init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = SupabaseAPI.storedSession()
    }

    var currentSession: SupabaseSession? { session }
    var userID: String? { session?.userID }

    /// Public URL of a file in a public bucket (`work`, `avatars`).
    nonisolated func publicURL(bucket: String, path: String) -> URL {
        baseURL.appendingPathComponent("storage/v1/object/public/\(bucket)/\(path)")
    }

    // MARK: Requests

    /// One call. `path` is relative to the project, e.g. "rest/v1/bookings" or "functions/v1/pay-booking".
    /// Signed in, it carries the user's token; signed out, the publishable key alone.
    func call(_ method: String, _ path: String, query: [URLQueryItem] = [], body: Data? = nil,
              prefer: String? = nil, contentType: String = "application/json", signedIn: Bool = true) async throws -> Data {
        var token: String? = nil
        if signedIn, session != nil {
            token = try await freshSession()?.accessToken
        }
        let first = try request(method, path, query: query, body: body, prefer: prefer, contentType: contentType, token: token)
        let (data, status) = try await perform(first)
        if status == 401, token != nil {
            let renewed = try await refresh()
            let second = try request(method, path, query: query, body: body, prefer: prefer, contentType: contentType, token: renewed.accessToken)
            let (data2, status2) = try await perform(second)
            return try check(data2, status: status2)
        }
        return try check(data, status: status)
    }

    private func request(_ method: String, _ path: String, query: [URLQueryItem], body: Data?, prefer: String?,
                         contentType: String, token: String?) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw DataError.network }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.timeoutInterval = 30
        r.setValue(apiKey, forHTTPHeaderField: "apikey")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let prefer { r.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let body {
            r.setValue(contentType, forHTTPHeaderField: "Content-Type")
            r.httpBody = body
        }
        return r
    }

    private func perform(_ request: URLRequest) async throws -> (Data, Int) {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return (data, status)
        } catch {
            throw DataError.network
        }
    }

    private func check(_ data: Data, status: Int) throws -> Data {
        if (200..<300).contains(status) { return data }
        throw SupabaseAPI.failure(data, status: status)
    }

    /// Pulls the useful word out of an error body. PostgREST: {message, code}; GoTrue: {error_code, msg}
    /// or {error, error_description}; our functions: {error}.
    static func failure(_ data: Data, status: Int) -> SupabaseFailure {
        var code = ""
        var message = ""
        if let object = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] {
            if let m = object["message"] as? String { message = m }
            else if let m = object["msg"] as? String { message = m }
            else if let m = object["error_description"] as? String { message = m }
            if let c = object["error_code"] as? String { code = c }
            else if let c = object["error"] as? String { code = c }
            else if let c = object["code"] as? String { code = c }
        }
        #if DEBUG
        print("Supabase \(status): \(code) \(message)")
        #endif
        return SupabaseFailure(status: status, code: code, message: message)
    }

    // MARK: Session

    private func freshSession() async throws -> SupabaseSession? {
        guard let s = session else { return nil }
        if s.expiresAt.timeIntervalSinceNow > 60 { return s }
        return try await refresh()
    }

    /// One refresh at a time; anyone else who needs it waits for the same one.
    private func refresh() async throws -> SupabaseSession {
        if let running = refreshing { return try await running.value }
        guard let token = session?.refreshToken else { throw DataError.notSignedIn }
        let task: Task<SupabaseSession, Error> = Task { try await self.exchange(refreshToken: token) }
        refreshing = task
        do {
            let fresh = try await task.value
            refreshing = nil
            return fresh
        } catch {
            refreshing = nil
            throw error
        }
    }

    private func exchange(refreshToken: String) async throws -> SupabaseSession {
        let body = try SupabaseJSON.body(["refresh_token": refreshToken])
        do {
            let data = try await call("POST", "auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                                      body: body, signedIn: false)
            return try adopt(data)
        } catch let failure as SupabaseFailure {
            // The refresh token is spent or revoked: signed out for real.
            if failure.status == 400 || failure.status == 401 || failure.status == 403 { clearSession() }
            throw DataError.notSignedIn
        }
    }

    private struct AuthUser: Decodable {
        let id: String
        let phone: String?
        let email: String?
    }

    private struct AuthReply: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Double?
        let expiresAt: Double?
        let user: AuthUser
    }

    /// Takes a GoTrue token reply as the new session.
    private func adopt(_ data: Data) throws -> SupabaseSession {
        let reply = try SupabaseJSON.decode(AuthReply.self, from: data)
        let expires: Date
        if let at = reply.expiresAt {
            expires = Date(timeIntervalSince1970: at)
        } else {
            expires = Date().addingTimeInterval(reply.expiresIn ?? 3600)
        }
        let s = SupabaseSession(
            accessToken: reply.accessToken,
            refreshToken: reply.refreshToken,
            expiresAt: expires,
            userID: reply.user.id,
            phone: reply.user.phone ?? "",
            email: reply.user.email ?? ""
        )
        session = s
        if let encoded = try? JSONEncoder().encode(s) { Keychain.write(encoded, for: SupabaseAPI.keychainAccount) }
        return s
    }

    private func clearSession() {
        session = nil
        Keychain.delete(SupabaseAPI.keychainAccount)
    }

    private static func storedSession() -> SupabaseSession? {
        guard let data = Keychain.read(keychainAccount) else { return nil }
        return try? JSONDecoder().decode(SupabaseSession.self, from: data)
    }

    // MARK: Auth

    /// Texts a code. `phone` is E.164, "+614…".
    func sendCode(phone: String) async throws {
        let body = try SupabaseJSON.body(["phone": phone])
        _ = try await call("POST", "auth/v1/otp", body: body, signedIn: false)
    }

    func verifyCode(phone: String, code: String) async throws -> SupabaseSession {
        let body = try SupabaseJSON.body(["phone": phone, "token": code, "type": "sms"])
        let data = try await call("POST", "auth/v1/verify", body: body, signedIn: false)
        return try adopt(data)
    }

    /// Sign in with Apple: the identity token and the raw nonce whose hash went into the request.
    func signIn(provider: String, idToken: String, nonce: String) async throws -> SupabaseSession {
        let body = try SupabaseJSON.body(["provider": provider, "id_token": idToken, "nonce": nonce])
        let data = try await call("POST", "auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "id_token")],
                                  body: body, signedIn: false)
        return try adopt(data)
    }

    /// Best effort on the server; always clears the phone.
    func signOut() async {
        if let s = session, let r = try? request("POST", "auth/v1/logout", query: [], body: nil, prefer: nil,
                                                 contentType: "application/json", token: s.accessToken) {
            _ = try? await perform(r)
        }
        clearSession()
    }

    /// Forgets the session without telling the server (after the account's been deleted).
    func forget() {
        clearSession()
    }
}
