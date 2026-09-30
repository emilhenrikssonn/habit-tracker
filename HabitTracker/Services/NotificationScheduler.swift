import Foundation
import SwiftData
import UserNotifications

/// Schedules every notification the app sends. They are local notifications: nothing leaves the device.
///
/// Pending notifications are rebuilt from the current habits, logs and settings each time this runs
/// (when the app opens or goes to the background, and when settings change), so checks like
/// "only if something is still open" use what has actually been logged.
@MainActor
enum NotificationScheduler {
    static let weeklyReportTime = "19:00"
    private static let daysAhead = 7
    private static let maxPending = 60 // iOS keeps at most 64 per app

    private static var center: UNUserNotificationCenter { .current() }

    static func status() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    static func isAllowed(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    /// Shows the system permission prompt if it hasn't been shown yet. Returns whether notifications are allowed.
    @discardableResult
    static func requestPermission() async -> Bool {
        let current = await status()
        guard current == .notDetermined else { return isAllowed(current) }
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func reschedule(in ctx: ModelContext) async {
        let requests = buildRequests(in: ctx, now: Date())
        center.removeAllPendingNotificationRequests()
        guard isAllowed(await status()) else { return }
        for request in requests {
            try? await center.add(request)
        }
    }

    // MARK: Building

    static func buildRequests(in ctx: ModelContext, now: Date) -> [UNNotificationRequest] {
        guard let prefs = try? ctx.fetch(FetchDescriptor<AppPrefs>()).first else { return [] }
        let habits = ((try? ctx.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortIndex)]))) ?? [])
            .filter { !$0.archived }
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        var pending: [(fire: Date, request: UNNotificationRequest)] = []

        func add(_ id: String, at time: String, on day: Date, title: String, body: String) {
            guard let fire = ClockTime.date(time, on: day), fire > now else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire),
                repeats: false
            )
            let identifier = "\(id).\(Int(day.timeIntervalSince1970))"
            pending.append((fire, UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)))
        }

        for offset in 0..<daysAhead {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let isToday = offset == 0
            let due = habits.filter { $0.isDue(on: day) }
            // Future days have nothing logged yet, so everything due is still open.
            let open = due.filter { !(isToday && $0.todayLog(on: day)?.completed == true) }

            if prefs.habitRemindersEnabled {
                for habit in open {
                    guard let time = habit.reminder else { continue }
                    add("habit.\(habit.id)", at: time, on: day, title: habit.name,
                        body: reminderBody(habit, isToday: isToday))
                }
            }

            if prefs.morningPlanEnabled, !due.isEmpty {
                add("morning", at: prefs.morningPlanTime, on: day, title: "Today's plan",
                    body: "\(count(due.count)) today: \(names(due)).")
            }

            if prefs.eveningCheckinEnabled, !open.isEmpty {
                let body = open.count == 1
                    ? "\(open[0].name) is still open. Log it before the day ends."
                    : "\(open.count) habits still open: \(names(open))."
                add("evening", at: prefs.eveningCheckinTime, on: day, title: "Evening check-in", body: body)
            }

            // A streak can only be at risk today; tomorrow's depends on what happens today.
            if isToday, prefs.streakRescueEnabled {
                for habit in open {
                    let streak = habit.stats(today: now).currentStreak
                    guard streak >= prefs.streakRescueMinDays else { continue }
                    add("rescue.\(habit.id)", at: prefs.streakRescueAlertTime, on: day,
                        title: "\(streak) days of \(habit.name) on the line",
                        body: rescueBody(habit))
                }
            }

            if prefs.weeklyReportEnabled, ClockTime.weekday(of: day) == prefs.weeklyReportWeekday {
                add("weekly", at: weeklyReportTime, on: day, title: "Your week in habits",
                    body: isToday ? weekSummary(habits, today: today) : "See how your week went in Stats.")
            }
        }

        return pending.sorted { $0.fire < $1.fire }.prefix(maxPending).map(\.request)
    }

    private static func reminderBody(_ habit: Habit, isToday: Bool) -> String {
        guard habit.isQuantified else {
            return habit.type == .quit ? "Stay on track today." : "Time to get it done today."
        }
        let logged = isToday ? habit.todayLog()?.value ?? 0 : 0
        if logged > 0 {
            return "\(habit.format(logged)) of \(habit.formatWithUnit(habit.dailyGoal)) so far."
        }
        return "Goal today: \(habit.formatWithUnit(habit.dailyGoal))."
    }

    private static func rescueBody(_ habit: Habit) -> String {
        guard habit.isQuantified else { return "Mark it done before midnight to keep the streak." }
        let logged = habit.todayLog()?.value ?? 0
        let left = max(0, habit.dailyGoal - logged)
        return "\(habit.format(logged)) of \(habit.formatWithUnit(habit.dailyGoal)) logged. \(habit.formatWithUnit(left)) left to keep the streak."
    }

    private static func weekSummary(_ habits: [Habit], today: Date) -> String {
        let cal = Calendar.current
        var due = 0, kept = 0
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            for habit in habits where habit.isDue(on: day) {
                due += 1
                if habit.todayLog(on: day)?.completed == true { kept += 1 }
            }
        }
        guard due > 0 else { return "See how your week went in Stats." }
        return "You kept \(kept) of \(due) habit days this week. Open Stats for the details."
    }

    private static func count(_ n: Int) -> String { n == 1 ? "1 habit" : "\(n) habits" }

    private static func names(_ habits: [Habit]) -> String {
        let shown = habits.prefix(3).map(\.name).joined(separator: ", ")
        return habits.count > 3 ? "\(shown) and \(habits.count - 3) more" : shown
    }
}
