import SwiftUI
import SwiftData

private enum StatsRange: String, CaseIterable, Identifiable {
    case week = "Week", twoWeeks = "2 weeks", month = "Month", halfYear = "6 months", year = "Year", custom = "Custom"
    var id: String { rawValue }
}

/// Completion across all active habits for a date range. Archived habits are left out.
struct StatisticsScreen: View {
    @Query(sort: [SortDescriptor(\Habit.sortIndex)]) private var habits: [Habit]
    @AppStorage("weekStart") private var weekStart = 1
    @State private var range: StatsRange = .month
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -29, to: Calendar.current.startOfDay(for: Date()))!
    @State private var customEnd = Calendar.current.startOfDay(for: Date())
    @State private var pickingDates = false

    private var active: [Habit] { habits.filter { !$0.archived } }
    private let cal = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBlock
            rangeTabs
            dateLine
            ScrollView {
                if active.isEmpty {
                    emptyState
                } else {
                    let summary = Summary(habits: active, start: interval.start, end: interval.end)
                    VStack(alignment: .leading, spacing: 24) {
                        completionBlock(summary)
                        weekdayBlock(summary)
                        perHabitBlock(summary)
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, AppMetrics.hPadding)
                }
            }
        }
        .sheet(isPresented: $pickingDates) {
            RangePickerSheet(start: customStart, end: customEnd) { start, end in
                customStart = start
                customEnd = end
                range = .custom
            } onClose: { pickingDates = false }
        }
    }

    // MARK: Range

    private var interval: (start: Date, end: Date) {
        let today = cal.startOfDay(for: Date())
        func back(_ component: Calendar.Component, _ n: Int) -> Date {
            cal.date(byAdding: .day, value: 1, to: cal.date(byAdding: component, value: -n, to: today)!)!
        }
        switch range {
        case .week: return (back(.day, 7), today)
        case .twoWeeks: return (back(.day, 14), today)
        case .month: return (back(.month, 1), today)
        case .halfYear: return (back(.month, 6), today)
        case .year: return (back(.year, 1), today)
        case .custom: return (customStart, customEnd)
        }
    }

    private var rangeDates: String {
        let (start, end) = interval
        let sameYear = cal.component(.year, from: start) == cal.component(.year, from: end)
            && cal.component(.year, from: end) == cal.component(.year, from: Date())
        let style: Date.FormatStyle = sameYear ? .dateTime.day().month(.abbreviated) : .dateTime.day().month(.abbreviated).year()
        return "\(start.formatted(style)) – \(end.formatted(style))"
    }

    private var titleBlock: some View {
        Text("Statistics")
            .font(AppFont.serif(40)).foregroundStyle(AppColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppMetrics.hPadding)
            .padding(.top, 20).padding(.bottom, 16)
    }

    private var rangeTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StatsRange.allCases) { r in
                    CategoryChip(title: r.rawValue, isActive: range == r) {
                        if r == .custom { pickingDates = true } else { range = r }
                    }
                }
            }
            .padding(.horizontal, AppMetrics.hPadding)
        }
        .padding(.bottom, 8)
    }

    private var dateLine: some View {
        HStack {
            Text(rangeDates).font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
            Spacer()
            Button { pickingDates = true } label: {
                Text(range == .custom ? "edit dates ›" : "pick dates ›")
                    .font(AppFont.mono(11)).foregroundStyle(AppColor.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppMetrics.hPadding)
        .padding(.bottom, 18)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HRule().padding(.bottom, 8)
            Text("No stats yet").font(AppFont.serif(28)).foregroundStyle(AppColor.ink)
            Text("Add a habit and log it for a few days to see your completion, streaks and best days here.")
                .font(AppFont.sans(15)).foregroundStyle(AppColor.inkDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppMetrics.hPadding)
    }

    // MARK: Blocks

    private func completionBlock(_ s: Summary) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(s.due == 0 ? "–" : "\(s.rate)%")
                    .font(AppFont.mono(46))
                    .foregroundStyle(AppColor.accent)
                Text("completion rate")
                    .font(AppFont.mono(11))
                    .foregroundStyle(AppColor.inkMute)
            }
            HStack(spacing: 10) {
                statCard("KEPT", "\(s.kept)/\(s.due)")
                statCard("BEST RUN", s.bestRun == 1 ? "1 day" : "\(s.bestRun) d")
                statCard("PERFECT DAYS", "\(s.perfectDays)")
            }
            Text("A perfect day is one where every habit due was kept. Best run is the most perfect days in a row. Habits still open today aren't counted until you tick them off.")
                .font(AppFont.sans(13)).foregroundStyle(AppColor.inkMute)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statCard(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFont.mono(10, weight: .medium))
                .tracking(10 * 0.16)
                .foregroundStyle(AppColor.inkMute)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(AppFont.mono(20))
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).fill(AppColor.surface))
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).stroke(AppColor.border, lineWidth: 1))
    }

    private func weekdayBlock(_ s: Summary) -> some View {
        let order = Habit.orderedWeekdays
        let rates = order.map { s.weekdayRate[$0] ?? nil }
        return VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "By weekday")
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(order.indices, id: \.self) { i in
                    weekdayBar(day: String(Habit.dayShort(order[i]).prefix(2)), value: rates[i])
                }
            }
            Text(weekdayInsight(s))
                .font(AppFont.sans(13))
                .foregroundStyle(AppColor.inkMute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .id(weekStart)
    }

    private func weekdayInsight(_ s: Summary) -> AttributedString {
        let known = s.weekdayRate.compactMap { day, rate in rate.map { (day, $0) } }
        guard known.count >= 2,
              let best = known.max(by: { $0.1 < $1.1 }),
              let worst = known.min(by: { $0.1 < $1.1 }),
              best.1 != worst.1 else {
            return AttributedString("Keep logging to see which days work best for you.")
        }
        let text = "\(ClockTime.weekdayName(best.0))s are your best day — kept **\(best.1)%**. \(ClockTime.weekdayName(worst.0))s lag at **\(worst.1)%**."
        return (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }

    private func weekdayBar(day: String, value: Int?) -> some View {
        VStack(spacing: 6) {
            Text(value.map { "\($0)%" } ?? "–")
                .font(AppFont.mono(10))
                .foregroundStyle(AppColor.inkMute)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            let v = value ?? 0
            let color: Color = v >= 80 ? AppColor.accent : (v >= 60 ? AppColor.accentMid : AppColor.borderStrong)
            RoundedRectangle(cornerRadius: 3).fill(color)
                .frame(width: 22, height: max(3, CGFloat(v) * 0.9))
            Text(day)
                .font(AppFont.mono(10))
                .foregroundStyle(AppColor.inkMute)
        }
        .frame(maxWidth: .infinity)
    }

    private func perHabitBlock(_ s: Summary) -> some View {
        let (start, end) = interval
        let length = (cal.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        let prevEnd = cal.date(byAdding: .day, value: -1, to: start)!
        let prevStart = cal.date(byAdding: .day, value: -(length - 1), to: prevEnd)!
        return VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Per habit")
            ForEach(active) { habit in
                let days = habit.dueDays(from: start, to: end)
                let previous = habit.dueDays(from: prevStart, to: prevEnd)
                perHabitRow(habit, days: days, previous: previous, start: start, end: end)
            }
        }
    }

    private func perHabitRow(_ habit: Habit, days: [(date: Date, kept: Bool)], previous: [(date: Date, kept: Bool)],
                             start: Date, end: Date) -> some View {
        let rate = Summary.rate(days)
        let prevRate = Summary.rate(previous)
        var trend = ""
        if let rate, let prevRate {
            let diff = rate - prevRate
            trend = diff == 0 ? " · same" : (diff > 0 ? " · up \(diff)" : " · down \(-diff)")
        }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(habit.name)
                    .font(AppFont.serif(21))
                    .foregroundStyle(AppColor.ink)
                Spacer()
                Text(rate.map { "\($0)%\(trend)" } ?? "not due yet")
                    .font(AppFont.mono(11))
                    .foregroundStyle(AppColor.inkMute)
                    .lineLimit(1)
            }
            heatmap(days: days, start: start, end: end)
        }
        .padding(.vertical, 10)
    }

    /// One cell per day for ranges up to a month, one per week (shaded by that week's rate) beyond that.
    private func heatmap(days: [(date: Date, kept: Bool)], start: Date, end: Date) -> some View {
        let byDay = Dictionary(days.map { ($0.date, $0.kept) }, uniquingKeysWith: { a, _ in a })
        let today = cal.startOfDay(for: Date())
        let last = min(cal.startOfDay(for: end), today)
        let total = (cal.dateComponents([.day], from: cal.startOfDay(for: start), to: last).day ?? 0) + 1
        var cells: [Color] = []
        if total <= 31 {
            for offset in 0..<max(total, 0) {
                let d = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: start))!
                switch byDay[d] {
                case true?: cells.append(AppColor.accent)
                case false?: cells.append(AppColor.borderStrong)
                case nil: cells.append(AppColor.border.opacity(0.35))
                }
            }
        } else {
            var weekStart = cal.startOfDay(for: start)
            while weekStart <= last {
                let weekDays = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }.filter { $0 <= last }
                let due = weekDays.compactMap { byDay[$0] }
                if due.isEmpty {
                    cells.append(AppColor.border.opacity(0.35))
                } else {
                    let r = Double(due.filter { $0 }.count) / Double(due.count)
                    cells.append(r >= 0.8 ? AppColor.accent : (r >= 0.5 ? AppColor.accentMid : AppColor.borderStrong))
                }
                weekStart = cal.date(byAdding: .day, value: 7, to: weekStart)!
            }
        }
        let spacing: CGFloat = cells.count > 40 ? 2 : (cells.count > 20 ? 3 : 4)
        return HStack(spacing: spacing) {
            ForEach(cells.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2).fill(cells[i]).frame(height: 14)
            }
        }
    }
}

/// Totals for every active habit over one date range.
private struct Summary {
    var due = 0
    var kept = 0
    var perfectDays = 0
    var bestRun = 0
    /// Monday=1…Sunday=7 → % kept, nil when nothing was due that weekday.
    var weekdayRate: [Int: Int?] = [:]

    var rate: Int { due == 0 ? 0 : Int((Double(kept) / Double(due) * 100).rounded()) }

    init(habits: [Habit], start: Date, end: Date) {
        var byDate: [Date: (due: Int, kept: Int)] = [:]
        var byWeekday: [Int: (due: Int, kept: Int)] = [:]
        for habit in habits {
            for day in habit.dueDays(from: start, to: end) {
                byDate[day.date, default: (0, 0)].due += 1
                byWeekday[ClockTime.weekday(of: day.date), default: (0, 0)].due += 1
                if day.kept {
                    byDate[day.date, default: (0, 0)].kept += 1
                    byWeekday[ClockTime.weekday(of: day.date), default: (0, 0)].kept += 1
                }
            }
        }
        due = byDate.values.reduce(0) { $0 + $1.due }
        kept = byDate.values.reduce(0) { $0 + $1.kept }

        // Today's open habits are left out of the totals, but the day isn't perfect until they're all kept.
        let today = Calendar.current.startOfDay(for: Date())
        let dueToday = habits.filter { $0.isDue(on: today) }.count

        var run = 0
        for date in byDate.keys.sorted() {
            let day = byDate[date]!
            if day.kept == (date == today ? max(day.due, dueToday) : day.due) {
                perfectDays += 1
                run += 1
                bestRun = max(bestRun, run)
            } else {
                run = 0
            }
        }
        for weekday in 1...7 {
            let w = byWeekday[weekday]
            weekdayRate[weekday] = (w?.due ?? 0) == 0 ? nil : Int((Double(w!.kept) / Double(w!.due) * 100).rounded())
        }
    }

    static func rate(_ days: [(date: Date, kept: Bool)]) -> Int? {
        guard !days.isEmpty else { return nil }
        return Int((Double(days.filter(\.kept).count) / Double(days.count) * 100).rounded())
    }
}

/// Tap a start day, then an end day.
private struct RangePickerSheet: View {
    var onPick: (Date, Date) -> Void
    var onClose: () -> Void
    @State private var start: Date
    @State private var end: Date?
    @State private var month: Date

    init(start: Date, end: Date, onPick: @escaping (Date, Date) -> Void, onClose: @escaping () -> Void) {
        self.onPick = onPick
        self.onClose = onClose
        _start = State(initialValue: start)
        _end = State(initialValue: end)
        _month = State(initialValue: end)
    }

    var body: some View {
        CalendarSheet(title: "Pick dates", subtitle: subtitle, onDone: {
            onPick(start, end ?? start)
            onClose()
        }) {
            MonthCalendar(month: $month, dayStyle: style, onTap: tap)
        }
    }

    private var subtitle: String {
        let fmt: Date.FormatStyle = .dateTime.day().month(.abbreviated).year()
        guard let end else { return "From \(start.formatted(fmt)) · now tap the last day" }
        return "\(start.formatted(fmt)) – \(end.formatted(fmt))"
    }

    private func tap(_ date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        guard day <= Calendar.current.startOfDay(for: Date()) else { return }
        if end == nil && day >= start {
            end = day
        } else {
            start = day
            end = nil
        }
    }

    private func style(_ date: Date) -> CalendarDayStyle {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        if day > cal.startOfDay(for: Date()) { return CalendarDayStyle(fill: .clear, text: AppColor.dimOff) }
        if cal.isDate(day, inSameDayAs: start) || (end.map { cal.isDate(day, inSameDayAs: $0) } ?? false) {
            return CalendarDayStyle(fill: AppColor.accent, text: AppColor.inkOnAccent)
        }
        if let end, day > start, day < end {
            return CalendarDayStyle(fill: AppColor.accentMid, text: AppColor.accentSoftLight)
        }
        return CalendarDayStyle()
    }
}
