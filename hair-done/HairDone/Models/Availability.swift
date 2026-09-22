import Foundation

enum Weekday: Int, CaseIterable, Codable, Hashable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var short: String {
        switch self {
        case .sunday: return "Sun"; case .monday: return "Mon"; case .tuesday: return "Tue"
        case .wednesday: return "Wed"; case .thursday: return "Thu"; case .friday: return "Fri"; case .saturday: return "Sat"
        }
    }
    var long: String {
        switch self {
        case .sunday: return "Sunday"; case .monday: return "Monday"; case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"; case .thursday: return "Thursday"; case .friday: return "Friday"; case .saturday: return "Saturday"
        }
    }
    /// Monday-first ordering for calendars.
    static var week: [Weekday] { [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday] }
}

/// Minutes since midnight, e.g. 9:00 → 540, 17:30 → 1050.
struct TimeRange: Hashable, Codable {
    var startMinutes: Int
    var endMinutes: Int

    static func hours(_ start: Int, _ end: Int) -> TimeRange { TimeRange(startMinutes: start * 60, endMinutes: end * 60) }

    var label: String { "\(clock(startMinutes)) to \(clock(endMinutes))" }
    func clock(_ m: Int) -> String {
        let h = m / 60, min = m % 60
        let suffix = h >= 12 ? "pm" : "am"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return min == 0 ? "\(h12) \(suffix)" : String(format: "%d:%02d %@", h12, min, suffix)
    }
}

/// A pro's weekly template plus days she's blocked out. Slots are generated from this.
struct WeeklyAvailability: Hashable, Codable {
    var hours: [Weekday: [TimeRange]]
    /// Whole days off, as start-of-day dates.
    var daysOff: [Date] = []
    /// Minutes she wants between jobs to pack up and drive.
    var bufferMinutes: Int = 30
    /// Slot granularity in minutes.
    var stepMinutes: Int = 30

    func isOff(_ day: Date) -> Bool {
        daysOff.contains { Calendar.current.isDate($0, inSameDayAs: day) }
    }

    func ranges(on day: Date) -> [TimeRange] {
        if isOff(day) { return [] }
        return hours[day.weekday] ?? []
    }

    static let standard = WeeklyAvailability(hours: [
        .monday: [.hours(9, 18)], .tuesday: [.hours(9, 18)], .wednesday: [.hours(9, 20)],
        .thursday: [.hours(9, 20)], .friday: [.hours(8, 21)], .saturday: [.hours(7, 21)], .sunday: [.hours(9, 15)]
    ])
}

/// One bookable start time on a given day.
struct TimeSlot: Identifiable, Hashable {
    var start: Date
    var isAvailable: Bool
    /// Why it isn't, in a few words, if it isn't. "She's booked" / "Too close to another job"
    var reason: String? = nil
    var id: Date { start }

    enum Period: String, CaseIterable { case morning = "Morning", afternoon = "Afternoon", evening = "Evening" }
    var period: Period {
        switch start.hourOfDay {
        case ..<12: return .morning
        case 12..<17: return .afternoon
        default: return .evening
        }
    }
}
