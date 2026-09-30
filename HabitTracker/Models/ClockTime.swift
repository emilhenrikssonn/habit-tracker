import Foundation

/// Times of day are stored as "HH:mm" strings (24-hour).
enum ClockTime {
    static func date(_ time: String, on day: Date) -> Date? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
    }

    static func string(from date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// Monday=1…Sunday=7, matching Habit.weekdays.
    static func weekday(of date: Date) -> Int {
        (Calendar.current.component(.weekday, from: date) + 5) % 7 + 1
    }

    static func weekdayName(_ n: Int) -> String {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][(n - 1 + 7) % 7]
    }
}
