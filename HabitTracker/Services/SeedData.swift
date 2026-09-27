import Foundation
import SwiftData

enum SeedData {
    static let didSeedKey = "didSeedV1"

    static func installIfNeeded(container: ModelContainer) {
        if UserDefaults.standard.bool(forKey: didSeedKey) { return }
        let ctx = ModelContext(container)
        seedPrefs(in: ctx)
        seedHabits(in: ctx)
        try? ctx.save()
        UserDefaults.standard.set(true, forKey: didSeedKey)
    }

    static func seedPrefs(in ctx: ModelContext) {
        let existing = try? ctx.fetch(FetchDescriptor<AppPrefs>())
        if existing?.isEmpty ?? true {
            ctx.insert(AppPrefs())
        }
    }

    static func seedHabits(in ctx: ModelContext) {
        let existing = try? ctx.fetch(FetchDescriptor<Habit>())
        guard existing?.isEmpty ?? true else { return }

        let today = Calendar.current.startOfDay(for: Date())

        // 7 habits matching the Today screen: 4 done, 3 unfinished
        let seed: [(String, HabitCategory, TrackingType, String, Double, RepeatMode, [Int], Double, Bool, String?)] = [
            // name, cat, tracking, unit, goal, mode, weekdays, todayValue, done, reminder
            ("Exercise", .movement, .time, "min", 30, .days, [1,2,3,4,5], 18, false, "07:00"),
            ("Read", .mind, .amount, "pages", 20, .daily, [1,2,3,4,5,6,7], 0, false, "22:00"),
            ("Sleep by 23:00", .health, .done, "", 1, .daily, [1,2,3,4,5,6,7], 0, false, nil),
            ("Drink water", .health, .amount, "glasses", 8, .daily, [1,2,3,4,5,6,7], 8, true, nil),
            ("Take vitamins", .health, .done, "", 1, .daily, [1,2,3,4,5,6,7], 1, true, "08:00"),
            ("Stretch", .movement, .time, "min", 10, .daily, [1,2,3,4,5,6,7], 10, true, nil),
            ("No sugar", .quit, .done, "", 1, .daily, [1,2,3,4,5,6,7], 1, true, nil)
        ]

        for (idx, s) in seed.enumerated() {
            let h = Habit(
                name: s.0, category: s.1, type: s.1 == .quit ? .quit : .build,
                tracking: s.2, unit: s.3, dailyGoal: s.4,
                repeatMode: s.5, weekdays: s.6,
                timeOfDay: "Anytime", reminder: s.9, sortIndex: idx
            )
            ctx.insert(h)

            let log = HabitLog(
                date: today,
                value: s.7,
                completed: s.8,
                skipped: false
            )
            log.habit = h
            ctx.insert(log)

            // seed some past history for statistics — last 30 days, roughly following the design
            let cal = Calendar.current
            for offset in 1...30 {
                guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                let rand = Double(offset % 7) / 7.0
                let complete = rand > 0.25
                let past = HabitLog(
                    date: d,
                    value: complete ? s.4 : s.4 * rand,
                    completed: complete,
                    skipped: false
                )
                past.habit = h
                ctx.insert(past)
            }
        }
    }
}
