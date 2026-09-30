import Foundation
import SwiftData

// Units, logging and statistics shared by every screen that shows or edits a habit.
extension Habit {
    var isQuantified: Bool { tracking != .done }

    /// The unit the habit is tracked in — the same one chosen when it was set up.
    var unitLabel: String {
        switch tracking {
        case .done: return ""
        case .time: return unit.isEmpty ? "min" : unit
        case .amount: return unit
        }
    }

    func format(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }

    /// "18 min", "20 pages", "3" — value followed by the habit's unit.
    func formatWithUnit(_ value: Double) -> String {
        unitLabel.isEmpty ? format(value) : "\(format(value)) \(unitLabel)"
    }

    /// Step sizes offered when logging, in the habit's own unit.
    var logSteps: [Double] {
        switch tracking {
        case .done: return []
        case .time: return [1, 5, 15]
        case .amount: return dailyGoal >= 10 ? [1, 5] : [1]
        }
    }

    // MARK: Logging

    func log(on date: Date = Date(), in ctx: ModelContext) -> HabitLog {
        if let existing = todayLog(on: date) { return existing }
        let l = HabitLog(date: date, value: 0, completed: false)
        l.habit = self
        ctx.insert(l)
        return l
    }

    /// Adds (or with a negative delta, removes) an amount for today, in the habit's unit.
    func add(_ delta: Double, in ctx: ModelContext) {
        let l = log(in: ctx)
        l.value = max(0, l.value + delta)
        l.completed = l.value >= dailyGoal
        try? ctx.save()
    }

    func toggleDone(in ctx: ModelContext) {
        let l = log(in: ctx)
        l.completed.toggle()
        if l.completed {
            if isQuantified && l.value < dailyGoal { l.value = dailyGoal }
            if !isQuantified { l.value = 1 }
        } else {
            l.value = 0
        }
        try? ctx.save()
    }

    // MARK: Timer

    var isTimerRunning: Bool { timerStartedAt != nil }

    func timerElapsed(at now: Date = Date()) -> TimeInterval {
        timerStartedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0
    }

    func startTimer(in ctx: ModelContext) {
        timerStartedAt = Date()
        try? ctx.save()
    }

    /// Stops the timer and logs the elapsed time to today, rounded to whole minutes.
    /// Returns the minutes logged (0 for runs under 30 seconds).
    @discardableResult
    func stopTimer(in ctx: ModelContext) -> Double {
        let minutes = (timerElapsed() / 60).rounded()
        timerStartedAt = nil
        if minutes > 0 { add(minutes, in: ctx) } else { try? ctx.save() }
        return minutes
    }

    func cancelTimer(in ctx: ModelContext) {
        timerStartedAt = nil
        try? ctx.save()
    }

    // MARK: Schedule & stats

    func isRestDay(_ date: Date) -> Bool {
        let cal = Calendar.current
        return restWeekdays.contains(ClockTime.weekday(of: date))
            || restDates.contains { cal.isDate($0, inSameDayAs: date) }
    }

    /// Whether the calendar rules put the habit on this day: started, not a rest day, and matching its repeat.
    func isScheduled(on date: Date) -> Bool {
        let cal = Calendar.current
        guard cal.startOfDay(for: date) >= cal.startOfDay(for: activeStart), !isRestDay(date) else { return false }
        switch repeatMode {
        case .daily, .weekly: return true
        case .days: return weekdays.contains(ClockTime.weekday(of: date))
        case .dates: return datesOfMonth.contains(cal.component(.day, from: date))
        }
    }

    /// Scheduled, and for "× per week" habits only until that week's target has been reached.
    func isDue(on date: Date) -> Bool { isDue(on: date, byDay: logsByDay) }

    private func isDue(on date: Date, byDay: [Date: HabitLog]) -> Bool {
        guard isScheduled(on: date) else { return false }
        guard repeatMode == .weekly else { return true }
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        var d = Habit.startOfWeek(containing: day)
        var kept = 0
        while d < day {
            if byDay[d]?.completed == true { kept += 1 }
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return kept < timesPerWeek
    }

    static func startOfWeek(containing date: Date) -> Date {
        let weekday = ClockTime.weekday(of: date)
        let back = weekStartsOnSunday ? weekday % 7 : weekday - 1
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: -back, to: cal.startOfDay(for: date))!
    }

    private var logsByDay: [Date: HabitLog] {
        let cal = Calendar.current
        return Dictionary(logs.map { (cal.startOfDay(for: $0.date), $0) }, uniquingKeysWith: { a, _ in a })
    }

    private var firstDay: Date {
        let cal = Calendar.current
        let earliestLog = logs.map(\.date).min() ?? createdAt
        return cal.startOfDay(for: min(earliestLog, createdAt))
    }

    struct Stats {
        var rate: Int            // % of scheduled days kept, last 30 days
        var average: Double      // per day in unit, or kept days per week for done habits
        var currentStreak: Int
        var bestStreak: Int
    }

    func stats(today: Date = Date()) -> Stats {
        let cal = Calendar.current
        let today = cal.startOfDay(for: today)
        let byDay = logsByDay
        let kept: (Date) -> Bool = { byDay[$0]?.completed == true }

        // Every due day from the first log to today; today only counts once it's kept.
        var days: [Date] = []
        var d = firstDay
        while d <= today {
            if isDue(on: d, byDay: byDay) && (d < today || kept(d)) { days.append(d) }
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }

        let windowStart = cal.date(byAdding: .day, value: -29, to: today)!
        let window = days.filter { $0 >= windowStart }
        let keptInWindow = window.filter(kept).count
        let rate = window.isEmpty ? 0 : Int((Double(keptInWindow) / Double(window.count) * 100).rounded())

        let average: Double
        if isQuantified {
            let total = window.reduce(0) { $0 + (byDay[$1]?.value ?? 0) }
            average = window.isEmpty ? 0 : total / Double(window.count)
        } else {
            average = window.isEmpty ? 0 : Double(keptInWindow) / Double(window.count) * 7
        }

        var best = 0, run = 0
        for day in days {
            run = kept(day) ? run + 1 : 0
            best = max(best, run)
        }
        var current = 0
        for day in days.reversed() {
            guard kept(day) else { break }
            current += 1
        }

        return Stats(rate: rate, average: average, currentStreak: current, bestStreak: best)
    }

    /// Every due day from `start` to `end` (inclusive) and whether it was kept.
    /// Today only counts once it's kept, and nothing after today counts.
    func dueDays(from start: Date, to end: Date, today: Date = Date()) -> [(date: Date, kept: Bool)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: today)
        let last = min(cal.startOfDay(for: end), today)
        let byDay = logsByDay
        var result: [(date: Date, kept: Bool)] = []
        var d = cal.startOfDay(for: start)
        while d <= last {
            let kept = byDay[d]?.completed == true
            if isDue(on: d, byDay: byDay) && (d < today || kept) { result.append((d, kept)) }
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return result
    }

    /// Values for the last `count` days, oldest first. Done habits report 1 for kept, 0 otherwise.
    func history(days count: Int, today: Date = Date()) -> [(date: Date, value: Double, kept: Bool)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: today)
        let byDay = logsByDay
        return (0..<count).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            let log = byDay[date]
            let kept = log?.completed == true
            return (date, isQuantified ? (log?.value ?? 0) : (kept ? 1 : 0), kept)
        }
    }
}
