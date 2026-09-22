import Foundation

/// Money is always stored in cents (Int) and shown in AUD.
enum Money {
    /// "$180" for whole dollars, "$47.50" otherwise.
    static func format(_ cents: Int, alwaysCents: Bool = false) -> String {
        let dollars = Double(cents) / 100
        if !alwaysCents && cents % 100 == 0 {
            return "$" + String(Int(dollars))
        }
        return String(format: "$%.2f", dollars)
    }
}

extension Date {
    /// "Tue 24 Sep"
    var shortDay: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_AU"); f.dateFormat = "EEE d MMM"; return f.string(from: self)
    }
    /// "6:15 pm"
    var clock: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_AU"); f.dateFormat = "h:mm a"
        return f.string(from: self).lowercased()
    }
    /// "Today", "Tomorrow", or "Tue 24 Sep"
    var friendlyDay: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "Today" }
        if cal.isDateInTomorrow(self) { return "Tomorrow" }
        if cal.isDateInYesterday(self) { return "Yesterday" }
        return shortDay
    }
    /// "Today, 6:15 pm"
    var friendlyDayTime: String { "\(friendlyDay), \(clock)" }
    /// "24 Sep 2026"
    var longDate: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_AU"); f.dateFormat = "d MMM yyyy"; return f.string(from: self)
    }
    var weekdayLetter: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_AU"); f.dateFormat = "EEEEE"; return f.string(from: self)
    }
    var dayNumber: String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: self)
    }
    var monthShort: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_AU"); f.dateFormat = "MMM"; return f.string(from: self)
    }
    func adding(minutes: Int) -> Date { addingTimeInterval(TimeInterval(minutes * 60)) }
    func adding(days: Int) -> Date { Calendar.current.date(byAdding: .day, value: days, to: self) ?? self }
    func adding(hours: Int) -> Date { addingTimeInterval(TimeInterval(hours * 3600)) }
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    func at(hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: self) ?? self
    }
    var hourOfDay: Int { Calendar.current.component(.hour, from: self) }
    var minuteOfHour: Int { Calendar.current.component(.minute, from: self) }
    var weekday: Weekday { Weekday(rawValue: Calendar.current.component(.weekday, from: self)) ?? .monday }
}

extension Int {
    /// 90 → "1 hr 30 min", 45 → "45 min", 120 → "2 hr"
    var minutesLabel: String {
        let h = self / 60, m = self % 60
        switch (h, m) {
        case (0, _): return "\(m) min"
        case (_, 0): return "\(h) hr"
        default: return "\(h) hr \(m) min"
        }
    }
}

extension Double {
    /// 1.2 → "1.2 km", 0.8 → "800 m", 12.4 → "12 km"
    var distanceLabel: String {
        if self < 1 { return "\(Int((self * 1000 / 50).rounded(.toNearestOrEven) * 50)) m" }
        if self < 10 { return String(format: "%.1f km", self) }
        return "\(Int(self.rounded())) km"
    }
    var ratingLabel: String { String(format: "%.1f", self) }
}

extension String {
    var initials: String {
        let parts = split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }.map(String.init)
        return letters.joined().uppercased()
    }
}
