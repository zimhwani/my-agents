import Foundation

/// The time she's still bookable, for Today's strip and "You've 31 hours open.": her hours on a day
/// (none when she's blocked it), less each job and request with her buffer either side, less
/// everything before now plus her notice. The same inputs the slots are made from, summed.
enum ProOpenHours {
    /// Open minutes on `day`.
    static func minutes(on day: Date, pro: Pro, bookings: [Booking], now: Date = Date()) -> Int {
        let midnight = day.startOfDay
        let ranges = pro.availability.ranges(on: midnight)
        guard !ranges.isEmpty else { return 0 }
        // Nothing sooner than her notice can be booked, and nothing in the past.
        let cutoff = Int(now.adding(minutes: pro.noticeMinutes).timeIntervalSince(midnight) / 60)
        var open: [TimeRange] = ranges.compactMap { r in
            let start = max(r.startMinutes, cutoff)
            return start < r.endMinutes ? TimeRange(startMinutes: start, endMinutes: r.endMinutes) : nil
        }
        let buffer = pro.availability.bufferMinutes
        for b in bookings where !b.status.isCancelled && Calendar.current.isDate(b.start, inSameDayAs: midnight) {
            let from = Int(b.start.timeIntervalSince(midnight) / 60) - buffer
            let to = from + buffer + b.minutes + buffer
            open = open.flatMap { r -> [TimeRange] in
                guard from < r.endMinutes, to > r.startMinutes else { return [r] }
                return [TimeRange(startMinutes: r.startMinutes, endMinutes: from),
                        TimeRange(startMinutes: to, endMinutes: r.endMinutes)]
                    .filter { $0.startMinutes < $0.endMinutes }
            }
        }
        return open.reduce(0) { $0 + $1.endMinutes - $1.startMinutes }
    }

    /// Seven days starting today, as Today's strip shows them.
    static func nextSevenDays(from now: Date = Date()) -> [Date] {
        (0..<7).map { now.startOfDay.adding(days: $0) }
    }

    /// Open minutes over the seven days from today.
    static func weekMinutes(pro: Pro, bookings: [Booking], now: Date = Date()) -> Int {
        nextSevenDays(from: now).reduce(0) { $0 + minutes(on: $1, pro: pro, bookings: bookings, now: now) }
    }

    /// Whole hours, rounded: 31.
    static func hours(_ minutes: Int) -> Int { Int((Double(minutes) / 60).rounded()) }

    // MARK: The one hours suggestion

    struct MorningSuggestion: Equatable {
        let day: Weekday
        /// When she starts that day now, in minutes since midnight.
        let startMinutes: Int
        static let opening = 9 * 60
        var addedMinutes: Int { startMinutes - Self.opening }
    }

    /// The first day she works (Monday first) that starts at 12 or later: opening it at 9 is the
    /// suggestion. One at a time; nil when no day qualifies. A rule, not a claim about demand.
    static func morningSuggestion(_ hours: [Weekday: [TimeRange]]) -> MorningSuggestion? {
        for day in Weekday.week {
            guard let start = hours[day]?.map(\.startMinutes).min(), start >= 12 * 60 else { continue }
            return MorningSuggestion(day: day, startMinutes: start)
        }
        return nil
    }
}
