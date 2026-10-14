import Foundation

/// Pro setup as far as she got, kept on the phone per user so she can leave and pick it up again.
/// Saved on every step she leaves. Once there's enough for a pro row (a specialty and a service),
/// the flow also saves a draft pro through `saveProSelf` with `isOnboarded = false`, which clients
/// can't see. Cleared when she finishes.
///
/// The You screen reads `ProOnboardingDraft.stepReached(userID:)` for
/// "Pick up where you left off. Step 4 of 7."
struct ProOnboardingDraft: Codable, Equatable {
    /// The step she'd reached, 1 to 7. Steps 0 (intro) and 8 (done) aren't kept.
    var step: Int
    var specialties: [Category] = []
    var services: [Service] = []
    var base: String = ""
    var latitude: Double? = nil
    var longitude: Double? = nil
    var radiusKm: Double = 10
    var feeText: String = "15"
    var hours: [Weekday: [TimeRange]] = WeeklyAvailability.standard.hours
    var bufferMinutes: Int = 30
    var noticeMinutes: Int = 90
    /// Only photos that finished uploading (they have an `imageURL`).
    var work: [WorkItem] = []
    var abn: String = ""

    static let totalSteps = 7

    private static func key(_ userID: String) -> String { "proOnboarding.draft.\(userID)" }

    /// The step she reached (1 to 7) if she left part way, else nil.
    static func stepReached(userID: String) -> Int? {
        guard let draft = load(userID: userID), draft.step >= 1 else { return nil }
        return min(draft.step, totalSteps)
    }

    static func load(userID: String) -> ProOnboardingDraft? {
        guard !userID.isEmpty, let data = UserDefaults.standard.data(forKey: key(userID)) else { return nil }
        return try? JSONDecoder().decode(ProOnboardingDraft.self, from: data)
    }

    func save(userID: String) {
        guard !userID.isEmpty, let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key(userID))
    }

    static func clear(userID: String) {
        guard !userID.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: key(userID))
    }
}
