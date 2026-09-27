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
    var activeStart: Date = Date()
    var activeEnd: Date? = nil
    var timeOfDay: String = "Anytime"
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
        switch repeatMode {
        case .daily: return "every day"
        case .days:
            if Set(weekdays) == Set(1...5) { return "Mon–Fri" }
            if Set(weekdays) == Set([6,7]) { return "weekends" }
            return weekdays.sorted().map { Habit.dayLetter($0) }.joined()
        case .weekly: return "\(timesPerWeek) × per week"
        case .dates: return "on dates"
        }
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
