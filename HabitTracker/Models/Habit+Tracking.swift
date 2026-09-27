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
        case .count, .amount: return unit
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
        case .count, .amount: return dailyGoal >= 10 ? [1, 5] : [1]
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

    // MARK: Schedule & stats

    func isScheduled(on date: Date) -> Bool {
        guard repeatMode == .days else { return true }
        let weekday = Calendar.current.component(.weekday, from: date) // Sun=1..Sat=7
        return weekdays.contains((weekday + 5) % 7 + 1)                 // Mon=1..Sun=7
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

        // Every day from the first log to today; today only counts once it's kept.
        var days: [Date] = []
        var d = firstDay
        while d <= today {
            if isScheduled(on: d) && (d < today || kept(d)) { days.append(d) }
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
