import SwiftUI
import SwiftData

struct HabitDetailScreen: View {
    @Environment(\.modelContext) private var ctx
    let habit: Habit
    var onClose: () -> Void

    var body: some View {
        ScreenScaffold {
            VStack(spacing: 0) {
                headerRow
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        titleBlock
                        logCard
                        statsRow
                        chartBlock
                        calendarBlock
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, AppMetrics.hPadding)
                }
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Button(action: onClose) {
                Text("‹ back").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
            }.buttonStyle(.plain)
            Spacer()
            Button {
                // edit stub
            } label: {
                Text("Edit").font(AppFont.mono(12)).foregroundStyle(AppColor.accent)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, AppMetrics.hPadding).padding(.top, 18).padding(.bottom, 20)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(habit.name)
                .font(AppFont.serif(40))
                .foregroundStyle(AppColor.ink)
            Text(metaLine)
                .font(AppFont.mono(11))
                .foregroundStyle(AppColor.inkMute)
        }
    }

    private var metaLine: String {
        let track: String
        switch habit.tracking {
        case .done: track = "done"
        case .count: track = "count · \(Int(habit.dailyGoal)) \(habit.unit)/day"
        case .amount: track = "amount · \(Int(habit.dailyGoal)) \(habit.unit)/day"
        case .time: track = "time · \(Int(habit.dailyGoal)) \(habit.unit)/day"
        }
        return "\(habit.category.display) · \(track) · \(habit.scheduleSummary)"
    }

    private var logCard: some View {
        let value = habit.todayLog()?.value ?? 0
        let goal = habit.dailyGoal
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today \(Int(value)) / \(Int(goal)) \(habit.unit.isEmpty ? "" : habit.unit)")
                    .font(AppFont.serif(22)).foregroundStyle(AppColor.ink)
                Spacer()
                MetaChip(text: "LOG")
            }
            ThinBar(progress: value / max(goal, 1), height: 6, track: AppColor.border, fill: AppColor.accent)
            HStack(spacing: 10) {
                actionPill("+5 min") { addValue(5) }
                actionPill("+15 min") { addValue(15) }
                actionPillFilled("Timer") { }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).fill(AppColor.surface))
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).stroke(AppColor.border, lineWidth: 1))
    }

    private func actionPill(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.mono(12)).foregroundStyle(AppColor.accent)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().stroke(AppColor.accentMid, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private func actionPillFilled(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.mono(12)).foregroundStyle(AppColor.inkOnAccent)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(AppColor.accent))
        }.buttonStyle(.plain)
    }

    private func addValue(_ delta: Double) {
        let today = Calendar.current.startOfDay(for: Date())
        let log = habit.todayLog() ?? {
            let l = HabitLog(date: today, value: 0, completed: false)
            l.habit = habit
            ctx.insert(l)
            return l
        }()
        log.value += delta
        if log.value >= habit.dailyGoal { log.completed = true }
        try? ctx.save()
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            stat("RATE", "83%")
            stat("AVG", "24 min")
            stat("STREAK", "6")
            stat("BEST", "14")
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: label)
            Text(value).font(AppFont.mono(20)).foregroundStyle(AppColor.ink)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColor.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColor.border, lineWidth: 1))
    }

    private var chartBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Minutes per day")
            let vals = (0..<14).map { _ in Int.random(in: 5...35) }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(vals.indices, id: \.self) { i in
                    let goal = Int(habit.dailyGoal)
                    let color: Color = vals[i] >= goal ? AppColor.accent : AppColor.accentMid
                    RoundedRectangle(cornerRadius: 3).fill(color)
                        .frame(width: 14, height: CGFloat(vals[i]) * 3)
                }
            }
            .frame(height: 110, alignment: .bottom)
            HStack {
                Text("13 Sep").font(AppFont.mono(10)).foregroundStyle(AppColor.inkMute)
                Spacer()
                Text("goal 30 min").font(AppFont.mono(10)).foregroundStyle(AppColor.inkMute)
                Spacer()
                Text("26 Sep").font(AppFont.mono(10)).foregroundStyle(AppColor.inkMute)
            }
        }
    }

    private var calendarBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "September")
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            let firstOfMonth = cal.date(from: cal.dateComponents([.year,.month], from: today))!
            let range = cal.range(of: .day, in: .month, for: firstOfMonth)!
            let firstWeekday = cal.component(.weekday, from: firstOfMonth) // Sun=1..Sat=7
            let offset = (firstWeekday + 5) % 7 // shift to Mon=0
            let cells: [Int?] = (0..<offset).map { _ in nil } + range.map { $0 }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(38), spacing: 6), count: 7), spacing: 6) {
                ForEach(0..<cells.count, id: \.self) { i in
                    if let day = cells[i] {
                        let date = cal.date(byAdding: .day, value: day-1, to: firstOfMonth)!
                        calendarCell(day: day, date: date)
                    } else {
                        Color.clear.frame(width: 26, height: 26)
                    }
                }
            }
        }
    }

    private func calendarCell(day: Int, date: Date) -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let isToday = cal.isDate(date, inSameDayAs: today)
        let log = habit.logs.first { cal.isDate($0.date, inSameDayAs: date) }
        let kept = log?.completed ?? false
        let color: Color
        if isToday { color = AppColor.accent }
        else if kept { color = AppColor.calendarKept }
        else { color = AppColor.surface }
        return Text("\(day)")
            .font(AppFont.mono(11))
            .foregroundStyle(isToday ? AppColor.inkOnAccent : AppColor.ink)
            .frame(width: 26, height: 26)
            .background(RoundedRectangle(cornerRadius: 6).fill(color))
    }
}
