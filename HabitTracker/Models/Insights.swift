import Foundation

// Deeper statistics built on due days and check-in times: momentum, getting back on track,
// which weekday streaks break on, personal records, time of day and habits done back to back.

typealias DueDay = (date: Date, kept: Bool)

extension Habit {
    /// Every due day since tracking began, oldest first.
    func allDueDays(today: Date = Date()) -> [DueDay] {
        dueDays(from: firstDay, to: today, today: today)
    }

    /// Times kept days were ticked off, between `start` and `end` inclusive. Older logs have no time.
    func checkIns(from start: Date, to end: Date) -> [Date] {
        let cal = Calendar.current
        let first = cal.startOfDay(for: start), last = cal.startOfDay(for: end)
        return logs.compactMap { log in
            guard log.completed, let at = log.completedAt, log.date >= first, log.date <= last else { return nil }
            return at
        }
    }
}

enum Insights {
    /// Saturday and Sunday, as Monday=1…Sunday=7.
    static let weekend: Set<Int> = [6, 7]

    static func percent(_ part: Int, of whole: Int) -> Int? {
        whole == 0 ? nil : Int((Double(part) / Double(whole) * 100).rounded())
    }

    static func days(from a: Date, to b: Date) -> Int {
        Calendar.current.dateComponents([.day], from: a, to: b).day ?? 0
    }

    static func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let s = values.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : Int((Double(s[s.count / 2 - 1] + s[s.count / 2]) / 2).rounded())
    }

    // MARK: Momentum

    /// 0–100: the share of due days kept, with each day counting half as much as one a week newer.
    /// Nil until at least three days have been due.
    static func momentum(_ lists: [[DueDay]], asOf day: Date, halfLife: Double = 7) -> Int? {
        let asOf = Calendar.current.startOfDay(for: day)
        var weight = 0.0, kept = 0.0, count = 0
        for days in lists {
            for d in days where d.date <= asOf {
                let w = pow(0.5, Double(Self.days(from: d.date, to: asOf)) / halfLife)
                weight += w
                count += 1
                if d.kept { kept += w }
            }
        }
        return count < 3 ? nil : Int((kept / weight * 100).rounded())
    }

    // MARK: Back on track

    struct Recovery {
        /// Median days from the first missed day to the next kept one. Nil before any comeback.
        var typicalDays: Int?
        var slips: Int
        /// Days since the current slip began, when the habit is off track right now.
        var currentGap: Int?
    }

    /// A slip starts on a missed day after a kept one and ends on the next kept day.
    static func recovery(_ lists: [[DueDay]], today: Date = Date()) -> Recovery? {
        var gaps: [Int] = []
        var current: Int? = nil
        for days in lists {
            var slipStart: Date? = nil
            var seenKept = false
            for d in days {
                if d.kept {
                    if let s = slipStart { gaps.append(Self.days(from: s, to: d.date)) }
                    slipStart = nil
                    seenKept = true
                } else if seenKept && slipStart == nil {
                    slipStart = d.date
                }
            }
            if let s = slipStart {
                let gap = Self.days(from: s, to: Calendar.current.startOfDay(for: today))
                current = max(current ?? 0, gap)
            }
        }
        guard !gaps.isEmpty || current != nil else { return nil }
        return Recovery(typicalDays: median(gaps), slips: gaps.count, currentGap: current)
    }

    // MARK: Streak risk

    struct StreakRisk {
        var weekday: Int
        /// % of streaks still going into that weekday that end on it.
        var rate: Int
        /// The same over every day, for comparison.
        var overall: Int
        /// Whether that day is clearly worse than the rest.
        var standsOut: Bool { rate >= overall + 8 }
    }

    /// The weekday a run of kept days most often ends on. Nil until a few streaks have broken.
    static func streakRisk(_ lists: [[DueDay]], minChances: Int = 4) -> StreakRisk? {
        var chances: [Int: Int] = [:], breaks: [Int: Int] = [:]
        for days in lists {
            for (prev, day) in zip(days, days.dropFirst()) where prev.kept {
                let w = ClockTime.weekday(of: day.date)
                chances[w, default: 0] += 1
                if !day.kept { breaks[w, default: 0] += 1 }
            }
        }
        let totalBreaks = breaks.values.reduce(0, +)
        guard totalBreaks >= 3,
              let overall = percent(totalBreaks, of: chances.values.reduce(0, +)),
              let worst = chances.filter({ $0.value >= minChances })
                  .map({ (day: $0.key, rate: percent(breaks[$0.key] ?? 0, of: $0.value)!) })
                  .max(by: { $0.rate < $1.rate }),
              worst.rate > 0 else { return nil }
        return StreakRisk(weekday: worst.day, rate: worst.rate, overall: overall)
    }

    // MARK: Records

    struct Run {
        var length: Int
        var start: Date
        var end: Date
    }

    /// The longest run of kept days in a row; on a tie, the most recent.
    static func longestRun(_ days: [DueDay]) -> Run? {
        var best: Run? = nil
        var start: Date? = nil, length = 0
        for d in days {
            guard d.kept else { start = nil; length = 0; continue }
            if start == nil { start = d.date }
            length += 1
            if length >= (best?.length ?? 1) { best = Run(length: length, start: start!, end: d.date) }
        }
        return best
    }

    /// Each day something was due, and whether everything due was kept.
    /// Today isn't perfect until every habit due today is done, ticked or not.
    static func perfectDays(_ lists: [[DueDay]], dueToday: Int, today: Date = Date()) -> [DueDay] {
        let today = Calendar.current.startOfDay(for: today)
        var byDate: [Date: (due: Int, kept: Int)] = [:]
        for days in lists {
            for d in days {
                byDate[d.date, default: (0, 0)].due += 1
                if d.kept { byDate[d.date, default: (0, 0)].kept += 1 }
            }
        }
        return byDate.keys.sorted().map { date in
            let day = byDate[date]!
            return (date, day.kept == (date == today ? max(day.due, dueToday) : day.due))
        }
    }

    /// Finished weeks, oldest first, and whether every day due in them was perfect.
    /// A week with nothing due counts as not perfect, so it ends a run.
    static func perfectWeeks(_ perfectDays: [DueDay], today: Date = Date()) -> [DueDay] {
        guard let first = perfectDays.first?.date else { return [] }
        let cal = Calendar.current
        var byWeek: [Date: Bool] = [:]
        for d in perfectDays {
            let week = Habit.startOfWeek(containing: d.date)
            byWeek[week] = (byWeek[week] ?? true) && d.kept
        }
        let thisWeek = Habit.startOfWeek(containing: today)
        var result: [DueDay] = []
        var week = Habit.startOfWeek(containing: first)
        while week < thisWeek {
            result.append((week, byWeek[week] ?? false))
            week = cal.date(byAdding: .day, value: 7, to: week)!
        }
        return result
    }

    struct BestMonth {
        var month: Date
        var rate: Int
        var kept: Int
        var due: Int
    }

    /// The calendar month with the highest share kept, among months with at least `minDue` due days.
    static func bestMonth(_ lists: [[DueDay]], minDue: Int = 10) -> BestMonth? {
        let cal = Calendar.current
        var byMonth: [Date: (due: Int, kept: Int)] = [:]
        for days in lists {
            for d in days {
                let month = cal.date(from: cal.dateComponents([.year, .month], from: d.date))!
                byMonth[month, default: (0, 0)].due += 1
                if d.kept { byMonth[month, default: (0, 0)].kept += 1 }
            }
        }
        return byMonth.filter { $0.value.due >= minDue }
            .map { BestMonth(month: $0.key, rate: percent($0.value.kept, of: $0.value.due)!, kept: $0.value.kept, due: $0.value.due) }
            .max { ($0.rate, $0.month) < ($1.rate, $1.month) }
    }

    // MARK: Time of day

    struct TimeOfDay {
        /// Check-ins per hour, 0…23.
        var hours: [Int]
        var total: Int
        var peakHour: Int
        /// Morning 5–12, afternoon 12–17, evening 17–22, night 22–5, as % of check-ins.
        var morning: Int, afternoon: Int, evening: Int, night: Int
        var beforeNoon: Int
    }

    static func timeOfDay(_ times: [Date]) -> TimeOfDay? {
        guard !times.isEmpty else { return nil }
        let cal = Calendar.current
        var hours = Array(repeating: 0, count: 24)
        for t in times { hours[cal.component(.hour, from: t)] += 1 }
        func share(_ range: [Int]) -> Int { percent(range.reduce(0) { $0 + hours[$1] }, of: times.count)! }
        return TimeOfDay(
            hours: hours,
            total: times.count,
            peakHour: hours.indices.max { hours[$0] < hours[$1] }!,
            morning: share(Array(5..<12)),
            afternoon: share(Array(12..<17)),
            evening: share(Array(17..<22)),
            night: share(Array(22..<24) + Array(0..<5)),
            beforeNoon: share(Array(0..<12))
        )
    }

    /// Median time of day as minutes after midnight. The day is taken to turn at 03:00,
    /// so check-ins either side of midnight sit together.
    static func typicalMinute(_ times: [Date]) -> Int? {
        let cal = Calendar.current
        let shifted = times.map { t in
            let c = cal.dateComponents([.hour, .minute], from: t)
            return ((c.hour ?? 0) * 60 + (c.minute ?? 0) - 180 + 1440) % 1440
        }
        return median(shifted).map { ($0 + 180) % 1440 }
    }

    static func clock(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    // MARK: Routines

    struct Routine {
        /// Indexes into the habits the routine was found among, in the order they're done.
        var members: [Int]
        /// Days the whole routine was done in this order.
        var days: Int
        /// Usual time the first habit is done, as minutes after midnight.
        var usualStart: Int?
    }

    /// Habits regularly done one after another, each within `maxGap` of the one before.
    /// `checkIns[i]` holds habit i's check-in times. Returns up to two routines with no habit in common.
    static func routines(_ checkIns: [[Date]], maxGap: TimeInterval = 90 * 60, minDays: Int = 3) -> [Routine] {
        let cal = Calendar.current
        // Day → habit index → check-in time.
        var byDay: [Date: [Int: Date]] = [:]
        for (i, times) in checkIns.enumerated() {
            for t in times { byDay[cal.startOfDay(for: t), default: [:]][i] = t }
        }
        func occurrences(_ chain: [Int]) -> [Date] {
            byDay.values.compactMap { day in
                let times = chain.compactMap { day[$0] }
                guard times.count == chain.count else { return nil }
                for (a, b) in zip(times, times.dropFirst()) where b <= a || b.timeIntervalSince(a) > maxGap { return nil }
                return times.first
            }
        }

        var found: [Routine] = []
        var used = Set<Int>()
        while found.count < 2 {
            let free = checkIns.indices.filter { !used.contains($0) && !checkIns[$0].isEmpty }
            var best: (chain: [Int], count: Int)? = nil
            for a in free {
                for b in free where a != b {
                    let n = occurrences([a, b]).count
                    if n >= minDays && n > (best?.count ?? 0) { best = ([a, b], n) }
                }
            }
            guard var chain = best?.chain else { break }
            // Grow at either end while the longer routine still happens often enough.
            while chain.count < 5 {
                var next: (chain: [Int], count: Int)? = nil
                for x in free where !chain.contains(x) {
                    for candidate in [chain + [x], [x] + chain] {
                        let n = occurrences(candidate).count
                        if n >= minDays && n > (next?.count ?? 0) { next = (candidate, n) }
                    }
                }
                guard let next else { break }
                chain = next.chain
            }
            let starts = occurrences(chain)
            found.append(Routine(members: chain, days: starts.count, usualStart: typicalMinute(starts)))
            used.formUnion(chain)
        }
        return found
    }
}

/// The deeper stats for a set of habits, worked out once per screen update.
/// Records, momentum and streak risk look at all history; the rest at `start`…`end`.
struct InsightReport {
    let habits: [Habit]
    let momentum: Int?
    let momentumWeekAgo: Int?
    /// Momentum on each of the last 30 days, oldest first.
    let momentumTrail: [Int?]
    let recovery: Insights.Recovery?
    /// Per habit, in the same order as `habits`.
    let recoveries: [Insights.Recovery?]
    let risk: Insights.StreakRisk?
    let longestStreak: (habit: Habit, run: Insights.Run)?
    let perfectRun: Insights.Run?
    let perfectWeekRun: Insights.Run?
    let perfectWeekTotal: Int
    let bestMonth: Insights.BestMonth?
    let timeOfDay: Insights.TimeOfDay?
    /// Per habit usual check-in time in the range, as minutes after midnight.
    let usualTimes: [Int?]
    let routines: [Insights.Routine]
    /// Weekday and weekend share kept in the range, overall and per habit.
    let weekdays: (due: Int, kept: Int)
    let weekends: (due: Int, kept: Int)
    let split: [(weekday: Int?, weekend: Int?)]
    /// Share of due habits kept on each day of roughly the last year. Days with nothing due are absent.
    let dailyShare: [Date: Double]

    init(habits: [Habit], start: Date, end: Date, today: Date = Date()) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: today)
        self.habits = habits
        let all = habits.map { $0.allDueDays(today: today) }
        let inRange = habits.map { $0.dueDays(from: start, to: end, today: today) }

        momentum = Insights.momentum(all, asOf: today)
        momentumWeekAgo = Insights.momentum(all, asOf: cal.date(byAdding: .day, value: -7, to: today)!)
        momentumTrail = (0..<30).reversed().map { Insights.momentum(all, asOf: cal.date(byAdding: .day, value: -$0, to: today)!) }

        recovery = Insights.recovery(all, today: today)
        recoveries = all.map { Insights.recovery([$0], today: today) }
        let halfYear = cal.date(byAdding: .month, value: -6, to: today)!
        risk = Insights.streakRisk(all.map { $0.filter { $0.date >= halfYear } })

        longestStreak = zip(habits, all)
            .compactMap { habit, days in Insights.longestRun(days).map { (habit, $0) } }
            .max { ($0.1.length, $0.1.end) < ($1.1.length, $1.1.end) }
        let dueToday = habits.filter { $0.isDue(on: today) }.count
        let perfect = Insights.perfectDays(all, dueToday: dueToday, today: today)
        perfectRun = Insights.longestRun(perfect)
        let weeks = Insights.perfectWeeks(perfect, today: today)
        perfectWeekRun = Insights.longestRun(weeks)
        perfectWeekTotal = weeks.filter(\.kept).count
        bestMonth = Insights.bestMonth(all)

        let checkIns = habits.map { $0.checkIns(from: start, to: end) }
        timeOfDay = Insights.timeOfDay(checkIns.flatMap { $0 })
        usualTimes = checkIns.map { Insights.typicalMinute($0) }
        routines = Insights.routines(checkIns)

        var wd = (due: 0, kept: 0), we = (due: 0, kept: 0)
        split = inRange.map { days in
            var d = (due: 0, kept: 0), e = (due: 0, kept: 0)
            for day in days {
                let isWeekend = Insights.weekend.contains(ClockTime.weekday(of: day.date))
                if isWeekend { e.due += 1; if day.kept { e.kept += 1 } } else { d.due += 1; if day.kept { d.kept += 1 } }
            }
            wd.due += d.due; wd.kept += d.kept; we.due += e.due; we.kept += e.kept
            return (Insights.percent(d.kept, of: d.due), Insights.percent(e.kept, of: e.due))
        }
        weekdays = wd
        weekends = we

        let yearAgo = cal.date(byAdding: .day, value: -371, to: today)!
        var tally: [Date: (due: Int, kept: Int)] = [:]
        for days in all {
            for d in days where d.date >= yearAgo {
                tally[d.date, default: (0, 0)].due += 1
                if d.kept { tally[d.date, default: (0, 0)].kept += 1 }
            }
        }
        dailyShare = tally.mapValues { Double($0.kept) / Double($0.due) }
    }
}
