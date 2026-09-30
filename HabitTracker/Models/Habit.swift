import Foundation
import SwiftData

@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var categoryRaw: String = HabitCategory.health.rawValue
    var typeRaw: String = HabitType.build.rawValue
    var trackingRaw: String = TrackingType.done.rawValue
    var unit: String = ""
    var dailyGoal: Double = 1
    var repeatModeRaw: String = RepeatMode.daily.rawValue
    var weekdays: [Int] = [1,2,3,4,5,6,7]
    var timesPerWeek: Int = 4
    var datesOfMonth: [Int] = []
    /// First day the habit is due. Days before it don't count in stats.
    var activeStart: Date = Date()
    var activeEnd: Date? = nil
    var timeOfDay: String = "Anytime"
    /// Weekdays (Monday=1…Sunday=7) the habit is never due.
    var restWeekdays: [Int] = []
    /// Specific days off, stored as start of day.
    var restDates: [Date] = []
    var reminder: String? = nil
    var archived: Bool = false
    var createdAt: Date = Date()
    var sortIndex: Int = 0
    /// Set while a timer is running for a time habit; persisted so it survives leaving the screen or app.
    var timerStartedAt: Date? = nil

    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
    var logs: [HabitLog] = []

    init(
        name: String,
        category: HabitCategory,
        type: HabitType = .build,
        tracking: TrackingType = .done,
        unit: String = "",
        dailyGoal: Double = 1,
        repeatMode: RepeatMode = .daily,
        weekdays: [Int] = [1,2,3,4,5,6,7],
        timeOfDay: String = "Anytime",
        reminder: String? = nil,
        sortIndex: Int = 0
    ) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.typeRaw = type.rawValue
        self.trackingRaw = tracking.rawValue
        self.unit = unit
        self.dailyGoal = dailyGoal
        self.repeatModeRaw = repeatMode.rawValue
        self.weekdays = weekdays
        self.timeOfDay = timeOfDay
        self.reminder = reminder
        self.sortIndex = sortIndex
        self.activeStart = Calendar.current.startOfDay(for: Date())
    }

    var category: HabitCategory {
        get { HabitCategory(rawValue: categoryRaw) ?? .health }
        set { categoryRaw = newValue.rawValue }
    }

    /// Display name for the habit's category — a built-in one or a custom name.
    var categoryName: String { Habit.categoryName(for: categoryRaw) }

    static func categoryName(for raw: String) -> String {
        HabitCategory(rawValue: raw)?.display ?? raw
    }
    var type: HabitType {
        get { HabitType(rawValue: typeRaw) ?? .build }
        set { typeRaw = newValue.rawValue }
    }
    var tracking: TrackingType {
        get { trackingRaw == "count" ? .amount : (TrackingType(rawValue: trackingRaw) ?? .done) }
        set { trackingRaw = newValue.rawValue }
    }
    var repeatMode: RepeatMode {
        get { RepeatMode(rawValue: repeatModeRaw) ?? .daily }
        set { repeatModeRaw = newValue.rawValue }
    }

    func todayLog(on date: Date = Date()) -> HabitLog? {
        let cal = Calendar.current
        return logs.first { cal.isDate($0.date, inSameDayAs: date) }
    }

    var goalString: String {
        switch tracking {
        case .done: return "Done / not done"
        case .amount: return "\(Int(dailyGoal)) \(unit)"
        case .time: return "\(Int(dailyGoal)) \(unit.isEmpty ? "min" : unit)"
        }
    }

    var scheduleSummary: String {
        let base: String
        switch repeatMode {
        case .daily: base = "every day"
        case .days:
            if Set(weekdays) == Set(1...5) { base = "Mon–Fri" }
            else if Set(weekdays) == Set([6,7]) { base = "weekends" }
            else { base = weekdays.sorted().map { Habit.dayLetter($0) }.joined() }
        case .weekly: base = "\(timesPerWeek) × per week"
        case .dates:
            base = datesOfMonth.isEmpty ? "no dates" : "monthly on " + datesOfMonth.sorted().map(String.init).joined(separator: ", ")
        }
        guard !restWeekdays.isEmpty else { return base }
        let off = Habit.orderedWeekdays.filter(restWeekdays.contains).map(Habit.dayShort).joined(separator: ", ")
        return repeatMode == .daily ? "every day but \(off)" : "\(base) · off \(off)"
    }

    /// Weekdays in display order, following the week-start setting.
    static var orderedWeekdays: [Int] { weekStartsOnSunday ? [7, 1, 2, 3, 4, 5, 6] : Array(1...7) }

    /// Shared with @AppStorage("weekStart") in Settings: 1 = Monday, 7 = Sunday.
    static var weekStartsOnSunday: Bool { UserDefaults.standard.integer(forKey: "weekStart") == 7 }

    static func dayShort(_ n: Int) -> String {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][(n - 1 + 7) % 7]
    }

    static func dayLetter(_ n: Int) -> String {
        // Monday=1..Sunday=7
        switch n {
        case 1: return "M"; case 2: return "T"; case 3: return "W"
        case 4: return "T"; case 5: return "F"; case 6: return "S"
        case 7: return "S"; default: return "?"
        }
    }
}
