import SwiftUI

// The deeper sections of Statistics, each drawn from one InsightReport.

private func insight(_ markdown: String) -> some View {
    Text((try? AttributedString(markdown: markdown)) ?? AttributedString(markdown))
        .font(AppFont.sans(13))
        .foregroundStyle(AppColor.inkMute)
        .fixedSize(horizontal: false, vertical: true)
}

private func dayCount(_ n: Int) -> String { n == 1 ? "1 day" : "\(n) days" }

/// Big number, recent trend and a 30-day line. Recent days weigh most.
struct MomentumBlock: View {
    let report: InsightReport

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Momentum")
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(report.momentum.map(String.init) ?? "–")
                    .font(AppFont.mono(46)).foregroundStyle(AppColor.accent)
                Text(trendLabel).font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
                Spacer()
            }
            Sparkline(values: report.momentumTrail).frame(height: 44)
            insight(caption)
        }
    }

    private var delta: Int? {
        guard let now = report.momentum, let before = report.momentumWeekAgo else { return nil }
        return now - before
    }

    private var trendLabel: String {
        guard let delta else { return "out of 100" }
        if delta >= 3 { return "▲ \(delta) vs a week ago" }
        if delta <= -3 { return "▼ \(-delta) vs a week ago" }
        return "steady vs a week ago"
    }

    private var caption: String {
        guard report.momentum != nil else { return "Log a few days to see your momentum." }
        let lead: String
        switch delta {
        case let d? where d >= 3: lead = "You're **picking up speed**."
        case let d? where d <= -3: lead = "You're **slowing down** — a couple of kept days turns it around."
        default: lead = "You're holding a **steady pace**."
        }
        return lead + " Momentum weighs recent days most: a day counts half as much as one a week newer."
    }
}

/// A thin line through the values, with gaps where a value is missing. Scaled to the values'
/// own range, at least 20 points tall, so a few points of change are visible.
private struct Sparkline: View {
    let values: [Int?]

    var body: some View {
        GeometryReader { g in
            let known = values.compactMap { $0 }
            let mid = Double((known.min() ?? 0) + (known.max() ?? 100)) / 2
            let half = max(Double((known.max() ?? 100) - (known.min() ?? 0)) / 2, 10)
            let low = min(max(mid - half, 0), 100 - 2 * half)
            let step = g.size.width / CGFloat(max(values.count - 1, 1))
            let y: (Int) -> CGFloat = { g.size.height * (1 - CGFloat((Double($0) - low) / (2 * half))) }
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: g.size.height))
                    p.addLine(to: CGPoint(x: g.size.width, y: g.size.height))
                }
                .stroke(AppColor.border, lineWidth: 1)
                Path { p in
                    var drawing = false
                    for (i, v) in values.enumerated() {
                        guard let v else { drawing = false; continue }
                        let pt = CGPoint(x: CGFloat(i) * step, y: y(v))
                        if drawing { p.addLine(to: pt) } else { p.move(to: pt) }
                        drawing = true
                    }
                }
                .stroke(AppColor.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                if let last = values.last, let last {
                    Circle().fill(AppColor.accent).frame(width: 7, height: 7)
                        .position(x: g.size.width, y: y(last))
                }
            }
        }
    }
}

/// Weekdays against weekends, overall and for the habits where they differ most.
struct WeekendSplitBlock: View {
    let report: InsightReport

    var body: some View {
        let weekday = Insights.percent(report.weekdays.kept, of: report.weekdays.due)
        let weekend = Insights.percent(report.weekends.kept, of: report.weekends.due)
        return VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Weekdays vs weekends")
            HStack(spacing: 10) {
                side("MON – FRI", weekday, kept: report.weekdays.kept, due: report.weekdays.due)
                side("SAT – SUN", weekend, kept: report.weekends.kept, due: report.weekends.due)
            }
            insight(summary(weekday, weekend))
            ForEach(rows, id: \.index) { row in
                habitRow(report.habits[row.index].name, row.weekday, row.weekend)
            }
        }
    }

    private func side(_ label: String, _ rate: Int?, kept: Int, due: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(AppFont.mono(10, weight: .medium)).tracking(1.6).foregroundStyle(AppColor.inkMute)
            Text(rate.map { "\($0)%" } ?? "–").font(AppFont.mono(28)).foregroundStyle(AppColor.ink)
            Text("\(kept)/\(due) kept").font(AppFont.mono(10)).foregroundStyle(AppColor.inkMute)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).fill(AppColor.surface))
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).stroke(AppColor.border, lineWidth: 1))
    }

    private func summary(_ weekday: Int?, _ weekend: Int?) -> String {
        guard let weekday, let weekend else { return "Needs both weekdays and weekends in the range to compare." }
        let gap = weekday - weekend
        if abs(gap) < 5 { return "About the same all week — your routine holds up on weekends." }
        return gap > 0
            ? "Weekends trail by **\(gap) points**. Habits below are the ones that slip most."
            : "You're stronger on weekends, by **\(-gap) points**. Habits below differ most."
    }

    /// Habits with both rates, biggest difference first, at most five.
    private var rows: [(index: Int, weekday: Int, weekend: Int)] {
        guard report.habits.count > 1 else { return [] }
        return report.split.enumerated()
            .compactMap { i, s in s.weekday.flatMap { d in s.weekend.map { (i, d, $0) } } }
            .sorted { abs($0.1 - $0.2) > abs($1.1 - $1.2) }
            .prefix(5)
            .map { (index: $0.0, weekday: $0.1, weekend: $0.2) }
    }

    private func habitRow(_ name: String, _ weekday: Int, _ weekend: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(AppFont.serif(19)).foregroundStyle(AppColor.ink).lineLimit(1)
                Spacer()
                Text("\(weekday)% · \(weekend)%").font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
            }
            ThinBar(progress: Double(weekday) / 100, height: 4, track: AppColor.border, fill: AppColor.accent)
            ThinBar(progress: Double(weekend) / 100, height: 4, track: AppColor.border, fill: AppColor.accentMid)
        }
    }
}

/// When check-ins happen: a 24-hour curve, the split across the day and each habit's usual time.
struct TimeOfDayBlock: View {
    let report: InsightReport

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Time of day")
            if let t = report.timeOfDay {
                curve(t)
                insight(caption(t))
                ForEach(usual, id: \.name) { row in
                    HStack {
                        Text(row.name).font(AppFont.serif(19)).foregroundStyle(AppColor.ink).lineLimit(1)
                        Spacer()
                        Text("usually \(Insights.clock(row.minute))").font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
                    }
                }
            } else {
                insight("Check-in times are recorded from now on. Tick off a few habits and the curve of when you do them shows up here.")
            }
        }
    }

    private func curve(_ t: Insights.TimeOfDay) -> some View {
        let top = max(t.hours.max() ?? 1, 1)
        return VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<24, id: \.self) { h in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(h == t.peakHour ? AppColor.accent : (t.hours[h] > 0 ? AppColor.accentMid : AppColor.border))
                        .frame(height: max(3, CGFloat(t.hours[h]) / CGFloat(top) * 70))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 70, alignment: .bottom)
            HStack {
                ForEach(["00", "06", "12", "18", "24"], id: \.self) { label in
                    Text(label).font(AppFont.mono(10)).foregroundStyle(AppColor.inkMute)
                    if label != "24" { Spacer() }
                }
            }
        }
    }

    private func caption(_ t: Insights.TimeOfDay) -> String {
        let lean = t.beforeNoon >= 50
            ? "**\(t.beforeNoon)%** of check-ins land before noon."
            : "**\(100 - t.beforeNoon)%** of check-ins land after noon."
        return "\(lean) Busiest hour: **\(Insights.clock(t.peakHour * 60))–\(Insights.clock((t.peakHour + 1) % 24 * 60))**. "
            + "Morning \(t.morning)% · afternoon \(t.afternoon)% · evening \(t.evening)% · night \(t.night)%."
    }

    private var usual: [(name: String, minute: Int)] {
        guard report.habits.count > 1 else { return [] }
        return zip(report.habits, report.usualTimes)
            .compactMap { habit, minute in minute.map { (habit.name, $0) } }
            .sorted { $0.1 < $1.1 }
    }
}

/// Habits regularly done back to back.
struct RoutinesBlock: View {
    let report: InsightReport

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Routines")
            if report.routines.isEmpty {
                insight(report.habits.count < 2
                        ? "Pick two or more habits to look for ones you do back to back."
                        : "No routine yet. When you often tick habits off within an hour and a half of each other, in the same order, they show up here.")
            } else {
                ForEach(report.routines.indices, id: \.self) { i in routine(report.routines[i]) }
                insight("Habits you often do one after another, each within 90 minutes of the last. Stacking a new habit onto one of these makes it easier to keep.")
            }
        }
    }

    private func routine(_ r: Insights.Routine) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(r.members.enumerated()), id: \.offset) { step, index in
                HStack(spacing: 10) {
                    Text("\(step + 1)").font(AppFont.mono(11)).foregroundStyle(AppColor.inkOnAccent)
                        .frame(width: 22, height: 22).background(Circle().fill(AppColor.accent))
                    Text(report.habits[index].name).font(AppFont.serif(19)).foregroundStyle(AppColor.ink).lineLimit(1)
                }
            }
            Text("together on \(dayCount(r.days))" + (r.usualStart.map { " · starts around \(Insights.clock($0))" } ?? ""))
                .font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).fill(AppColor.surface))
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).stroke(AppColor.border, lineWidth: 1))
    }
}

/// Which weekday streaks tend to break on, and how quickly you get back on track.
struct SlipsBlock: View {
    let report: InsightReport

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Slips & comebacks")
            insight(riskText)
            insight(recoveryText)
            ForEach(rows, id: \.name) { row in
                HStack {
                    Text(row.name).font(AppFont.serif(19)).foregroundStyle(AppColor.ink).lineLimit(1)
                    Spacer()
                    Text(row.text).font(AppFont.mono(11)).foregroundStyle(row.off ? AppColor.accent : AppColor.inkMute)
                }
            }
        }
    }

    private var riskText: String {
        guard let r = report.risk else { return "Not enough broken streaks yet to spot a risky day — that's a good thing." }
        guard r.standsOut else { return "No single day stands out: your streaks break about evenly across the week." }
        return "Based on the last six months, **\(ClockTime.weekdayName(r.weekday))s** are when streaks usually break — "
            + "\(r.rate)% of streaks going into one end there, against \(r.overall)% on an average day."
    }

    private var recoveryText: String {
        guard let r = report.recovery, let typical = r.typicalDays else {
            return "No slips to bounce back from yet."
        }
        let pace = typical <= 1 ? "the very next day" : "within **\(dayCount(typical))**"
        return "After a miss you're usually back on track \(pace), across \(r.slips) slip\(r.slips == 1 ? "" : "s")."
    }

    private var rows: [(name: String, text: String, off: Bool)] {
        guard report.habits.count > 1 else { return [] }
        return zip(report.habits, report.recoveries).compactMap { habit, r in
            guard let r else { return nil }
            if let gap = r.currentGap, gap > 0 { return (habit.name, "off track \(dayCount(gap))", true) }
            guard let typical = r.typicalDays else { return nil }
            return (habit.name, typical <= 1 ? "back next day" : "back in ~\(dayCount(typical))", false)
        }
    }
}

/// Bests across all history, newest first.
struct RecordsBlock: View {
    let report: InsightReport

    private struct Record {
        var title: String
        var value: String
        var detail: String
        var date: Date
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Personal records · all time")
            if records.isEmpty {
                insight("Your longest streak, best month and perfect weeks will be listed here as you set them.")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(records.indices, id: \.self) { i in row(records[i], last: i == records.count - 1) }
                }
            }
        }
    }

    private static let dayFmt = Date.FormatStyle().day().month(.abbreviated)

    private func span(_ run: Insights.Run) -> String {
        run.length == 1 ? run.end.formatted(Self.dayFmt) : "\(run.start.formatted(Self.dayFmt)) – \(run.end.formatted(Self.dayFmt))"
    }

    private var records: [Record] {
        var list: [Record] = []
        if let s = report.longestStreak {
            list.append(Record(title: "Longest streak", value: dayCount(s.run.length),
                               detail: "\(s.habit.name) · \(span(s.run))", date: s.run.end))
        }
        if report.habits.count > 1, let run = report.perfectRun {
            list.append(Record(title: "Most perfect days in a row", value: dayCount(run.length),
                               detail: "every habit kept · \(span(run))", date: run.end))
        }
        if let run = report.perfectWeekRun {
            let end = Calendar.current.date(byAdding: .day, value: 6, to: run.end)!
            list.append(Record(title: "Most perfect weeks in a row", value: run.length == 1 ? "1 week" : "\(run.length) weeks",
                               detail: "\(report.perfectWeekTotal) perfect week\(report.perfectWeekTotal == 1 ? "" : "s") in all · ended \(end.formatted(Self.dayFmt))",
                               date: end))
        }
        if let m = report.bestMonth {
            let cal = Calendar.current
            let monthEnd = cal.date(byAdding: DateComponents(month: 1, day: -1), to: m.month)!
            list.append(Record(title: "Best month", value: "\(m.rate)%",
                               detail: "\(m.month.formatted(.dateTime.month(.wide).year())) · \(m.kept)/\(m.due) kept",
                               date: min(monthEnd, cal.startOfDay(for: Date()))))
        }
        return list.sorted { $0.date > $1.date }
    }

    private func row(_ r: Record, last: Bool) -> some View {
        let isNew = Insights.days(from: r.date, to: Calendar.current.startOfDay(for: Date())) < 7
        return HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle().fill(isNew ? AppColor.accent : AppColor.accentMid).frame(width: 9, height: 9).padding(.top, 5)
                if !last { Rectangle().fill(AppColor.border).frame(width: 1).frame(maxHeight: .infinity) }
            }
            .frame(width: 9)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(r.date.formatted(.dateTime.day().month(.abbreviated).year()).uppercased())
                        .font(AppFont.mono(10, weight: .medium)).tracking(1).foregroundStyle(AppColor.inkMute)
                    if isNew { Text("NEW").font(AppFont.mono(9, weight: .medium)).foregroundStyle(AppColor.accent) }
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(r.title).font(AppFont.serif(19)).foregroundStyle(AppColor.ink)
                    Spacer()
                    Text(r.value).font(AppFont.mono(15)).foregroundStyle(AppColor.accent)
                }
                Text(r.detail).font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
            }
            .padding(.bottom, last ? 0 : 18)
        }
    }
}

/// The last year, shaded by the share of habits kept each day.
struct YearGraphBlock: View {
    let report: InsightReport

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Last 12 months")
            ContributionGraph { report.dailyShare[Calendar.current.startOfDay(for: $0)] }
        }
    }
}
