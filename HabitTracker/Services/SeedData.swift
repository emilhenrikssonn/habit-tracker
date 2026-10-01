import Foundation
import SwiftData

enum SeedData {
    /// Makes sure the settings row exists. New installs start with no habits; onboarding adds the first ones.
    static func installIfNeeded(container: ModelContainer) {
        let ctx = ModelContext(container)
        let existing = try? ctx.fetch(FetchDescriptor<AppPrefs>())
        guard existing?.isEmpty ?? true else { return }
        let prefs = AppPrefs()
        ctx.insert(prefs)
        #if DEBUG
        if ProcessInfo.processInfo.environment["DEMO_DATA"] == "1" { installDemo(prefs: prefs, in: ctx) }
        #endif
        try? ctx.save()
    }

    #if DEBUG
    /// Sample habits with two months of history, for App Store screenshots. Debug builds only,
    /// and only on a fresh install launched with DEMO_DATA=1 (DEMO_VIEW=grid for the grid layout).
    private static func installDemo(prefs: AppPrefs, in ctx: ModelContext) {
        prefs.hasOnboarded = true
        prefs.displayName = "Alex"
        if ProcessInfo.processInfo.environment["DEMO_VIEW"] == "grid" { prefs.defaultView = .grid }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -60, to: today)!
        // (habit, how often a past day is missed, today's value)
        let demo: [(Habit, Int, Double)] = [
            (Habit(name: "Drink water", category: .health, tracking: .amount, unit: "glasses", dailyGoal: 8), 9, 5),
            (Habit(name: "Take vitamins", category: .health), 14, 1),
            (Habit(name: "Morning walk", category: .movement, tracking: .time, unit: "min", dailyGoal: 30), 6, 30),
            (Habit(name: "Read", category: .mind, tracking: .amount, unit: "pages", dailyGoal: 20), 5, 20),
            (Habit(name: "Meditate", category: .mind, tracking: .time, unit: "min", dailyGoal: 10), 4, 0),
            (Habit(name: "No phone in bed", category: .quit, type: .quit), 7, 0),
        ]
        for (index, entry) in demo.enumerated() {
            let (habit, missEvery, todayValue) = entry
            habit.sortIndex = index
            habit.activeStart = start
            habit.createdAt = start
            ctx.insert(habit)
            for back in 1...60 where (back + index * 2) % missEvery != 0 {
                let log = HabitLog(date: cal.date(byAdding: .day, value: -back, to: today)!,
                                   value: habit.dailyGoal, completed: true)
                log.habit = habit
                ctx.insert(log)
            }
            if todayValue > 0 {
                let log = HabitLog(date: today, value: todayValue, completed: todayValue >= habit.dailyGoal)
                log.habit = habit
                ctx.insert(log)
            }
        }
    }
    #endif
}
