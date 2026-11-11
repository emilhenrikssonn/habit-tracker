import SwiftUI
import SwiftData

struct HabitDetailScreen: View {
    @Environment(\.modelContext) private var ctx
    let habit: Habit
    var onClose: () -> Void
    /// Asks the presenter to delete the habit once this screen has closed.
    var onDelete: () -> Void

    @State private var editing = false
    @State private var confirmingArchive = false
    @State private var confirmingDelete = false
    @State private var entering: Habit? = nil
    @State private var calendarMonth = Date()
    @State private var selectedBar: Int? = nil
    @AppStorage("habitChartDays") private var chartDays = 14

    var body: some View {
        ScreenScaffold {
            VStack(spacing: 0) {
                headerRow
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        titleBlock
                        logCard
                        statsRow
                        insightsBlock
                        chartBlock
                        yearBlock
                        calendarBlock
                        archiveBlock
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, AppMetrics.hPadding)
                }
            }
        }
        .sheet(isPresented: $editing) {
            HabitSetupScreen(editing: habit, onClose: { editing = false })
        }
        .confirmationDialog("Archive \(habit.name)?", isPresented: $confirmingArchive, titleVisibility: .visible) {
            Button("Archive") { archive() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It leaves Today, Stats and reminders. Its history is kept, and you can reactivate it from Habits → Archived.")
        }
        .confirmationDialog("Delete \(habit.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete for good", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its whole history is removed from this iPhone. This can't be undone. Archive it instead to keep the history.")
        }
        .amountEntry(for: $entering)
    }

    private var headerRow: some View {
        HStack {
            Button(action: onClose) {
                Text("‹ back").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
            }.buttonStyle(.plain)
            Spacer()
            Button {
                editing = true
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
        let track = habit.isQuantified
            ? "\(habit.tracking.display.lowercased()) · \(habit.formatWithUnit(habit.dailyGoal))/day"
            : "done"
        return "\(habit.categoryName) · \(track) · \(habit.scheduleSummary)"
    }

    private var logCard: some View {
        let value = habit.todayLog()?.value ?? 0
        let done = habit.todayLog()?.completed == true
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(habit.isQuantified
                     ? "Today \(habit.format(value)) / \(habit.formatWithUnit(habit.dailyGoal))"
                     : (done ? "Kept today" : "Not done yet"))
                    .font(AppFont.serif(22)).foregroundStyle(AppColor.ink)
                Spacer()
                if habit.isQuantified {
                    Button { entering = habit } label: {
                        Text("enter ›").font(AppFont.mono(12)).foregroundStyle(AppColor.accent)
                    }
                    .buttonStyle(.plain)
                } else {
                    MetaChip(text: "LOG")
                }
            }
            if habit.isQuantified {
                ThinBar(progress: value / max(habit.dailyGoal, 1), height: 6, track: AppColor.border, fill: AppColor.accent)
                HStack(spacing: 8) {
                    ForEach(minusSteps.reversed(), id: \.self) { step in
                        actionPill("−\(habit.format(step))", fill: true) { habit.add(-step, in: ctx) }
                            .disabled(value <= 0)
                            .opacity(value <= 0 ? 0.4 : 1)
                    }
                    ForEach(habit.logSteps, id: \.self) { step in
                        actionPill("+\(habit.format(step))", fill: true) { habit.add(step, in: ctx) }
                    }
                }
                if habit.tracking == .time { timerRow }
            } else {
                HStack(spacing: 10) {
                    if done {
                        actionPill("Undo") { habit.toggleDone(in: ctx) }
                    } else {
                        actionPillFilled("Mark done") { habit.toggleDone(in: ctx) }
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).fill(AppColor.surface))
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).stroke(AppColor.border, lineWidth: 1))
    }

    @ViewBuilder
    private var timerRow: some View {
        if habit.isTimerRunning {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = habit.timerElapsed(at: context.date)
                HStack(spacing: 10) {
                    Circle().fill(AppColor.accent).frame(width: 8, height: 8)
                    Text(Self.clock(elapsed))
                        .font(AppFont.mono(24)).foregroundStyle(AppColor.ink)
                        .monospacedDigit()
                    Spacer()
                    actionPill("Cancel") { habit.cancelTimer(in: ctx) }
                    actionPillFilled(elapsed < 30 ? "Stop" : "Stop · log \(Int((elapsed / 60).rounded())) min") {
                        habit.stopTimer(in: ctx)
                    }
                }
            }
            .padding(.top, 4)
        } else {
            Button { habit.startTimer(in: ctx) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                    Text("Start timer")
                }
                .font(AppFont.mono(13)).foregroundStyle(AppColor.inkOnAccent)
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(Capsule().fill(AppColor.accent))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    /// Amounts get a minus for every plus step; time keeps one small minus to fix a slip.
    private var minusSteps: [Double] {
        habit.tracking == .amount ? habit.logSteps : [habit.quickStep]
    }

    /// 04:12, or 1:04:12 past an hour.
    private static func clock(_ t: TimeInterval) -> String {
        let s = Int(t)
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
            : String(format: "%02d:%02d", s / 60, s % 60)
    }

    /// `fill` shares the row's width between the pills, for rows of up to four steps.
    private func actionPill(_ label: String, fill: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.mono(12)).foregroundStyle(AppColor.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, fill ? 6 : 14).padding(.vertical, 8)
                .frame(maxWidth: fill ? .infinity : nil)
                .background(Capsule().stroke(AppColor.accentMid, lineWidth: 1))
                .contentShape(Capsule())
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

    private var statsRow: some View {
        let st = habit.stats()
        let avg = habit.isQuantified
            ? habit.formatWithUnit((st.average * 10).rounded() / 10)
            : String(format: "%.1f days", st.average)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            stat("Rate · 30 days", "\(st.rate)%")
            stat(habit.isQuantified ? "Avg / day" : "Avg / week", avg)
            stat("Current streak", days(st.currentStreak))
            stat("Best streak", days(st.bestStreak))
        }
    }

    private func days(_ n: Int) -> String { n == 1 ? "1 day" : "\(n) days" }

    private var insightsBlock: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let report = InsightReport(habits: [habit], start: Calendar.current.date(byAdding: .day, value: -89, to: today)!, end: today)
        let recovery = report.recoveries.first ?? nil
        let back: String
        if let gap = recovery?.currentGap, gap > 0 { back = "off \(days(gap))" }
        else if let typical = recovery?.typicalDays { back = typical <= 1 ? "next day" : "~\(days(typical))" }
        else { back = "no slips" }
        let risky = report.risk.flatMap { $0.standsOut ? Habit.dayShort($0.weekday) + "s" : nil } ?? "none yet"
        return VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                stat("Momentum", report.momentum.map { "\($0) / 100" } ?? "–")
                stat("Back on track", back)
                stat("Usually done", report.usualTimes.first.flatMap { $0 }.map(Insights.clock) ?? "–")
                stat("Riskiest day", risky)
            }
            if let r = report.risk, r.standsOut {
                Text("\(r.rate)% of streaks going into a \(ClockTime.weekdayName(r.weekday)) end there, against \(r.overall)% on other days.")
                    .font(AppFont.sans(13)).foregroundStyle(AppColor.inkMute)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var yearBlock: some View {
        let byDay = Dictionary(habit.dueDays(from: Calendar.current.date(byAdding: .day, value: -371, to: Date())!, to: Date())
            .map { ($0.date, $0.kept) }, uniquingKeysWith: { a, _ in a })
        let logs = habit.logsByDay
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Last 12 months")
            ContributionGraph { date in
                let day = Calendar.current.startOfDay(for: date)
                guard let kept = byDay[day] else { return nil }
                if kept || !habit.isQuantified { return kept ? 1 : 0 }
                // Partly logged amounts and times show as a lighter shade.
                return min((logs[day]?.value ?? 0) / max(habit.dailyGoal, 1), 0.99)
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: label)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(AppFont.mono(20)).foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 72, maxHeight: 72, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColor.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColor.border, lineWidth: 1))
    }

    private static let chartRanges = [7, 14, 30, 90]
    private static let barMaxHeight: CGFloat = 100

    private var chartBlock: some View {
        let data = habit.history(days: chartDays)
        // Scale from past days and the goal only, so logging today never resizes the other bars.
        // Today's bar is capped at full height if it goes past that.
        let pastMax = data.dropLast().map(\.value).max() ?? 0
        let scale = max(pastMax, habit.isQuantified ? habit.dailyGoal * 1.25 : 1, 1)
        let dayFmt = Date.FormatStyle().day().month(.abbreviated)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: habit.isQuantified ? "\(habit.unitLabel.isEmpty ? "Amount" : habit.unitLabel) per day" : "Kept per day")
                Spacer()
                HStack(spacing: 0) {
                    ForEach(Self.chartRanges, id: \.self) { days in
                        Button {
                            selectedBar = nil
                            chartDays = days
                        } label: {
                            Text("\(days)d")
                                .font(AppFont.mono(11, weight: .medium))
                                .foregroundStyle(chartDays == days ? AppColor.inkOnAccent : AppColor.inkDim)
                                .padding(.horizontal, 9).padding(.vertical, 5)
                                .background(Capsule().fill(chartDays == days ? AppColor.accent : Color.clear))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Capsule().fill(AppColor.surface))
            }
            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(data.indices, id: \.self) { i in
                    bar(data[i], index: i, scale: scale)
                }
            }
            .frame(height: Self.barMaxHeight, alignment: .bottom)
            .overlay(alignment: .bottom) {
                if habit.isQuantified {
                    Rectangle()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(AppColor.inkMute.opacity(0.6))
                        .frame(height: 1)
                        .offset(y: -CGFloat(habit.dailyGoal / scale) * Self.barMaxHeight)
                        .allowsHitTesting(false)
                }
            }
            .padding(.top, 34) // room for the value bubble above the tallest bar
            HStack {
                Text(data.first!.date.formatted(dayFmt)).font(AppFont.mono(10)).foregroundStyle(AppColor.inkMute)
                Spacer()
                if habit.isQuantified {
                    Text("goal \(habit.formatWithUnit(habit.dailyGoal))").font(AppFont.mono(10)).foregroundStyle(AppColor.inkMute)
                    Spacer()
                }
                Text(data.last!.date.formatted(dayFmt)).font(AppFont.mono(10)).foregroundStyle(AppColor.inkMute)
            }
        }
    }

    private var barSpacing: CGFloat {
        switch chartDays {
        case ...14: return 6
        case ...30: return 3
        default: return 1
        }
    }

    private func bar(_ day: (date: Date, value: Double, kept: Bool), index i: Int, scale: Double) -> some View {
        let selected = selectedBar == i
        let height = max(chartDays > 30 ? 2 : 3, CGFloat(min(day.value / scale, 1)) * Self.barMaxHeight)
        let color: Color = selected ? AppColor.ink : (day.kept ? AppColor.accent : AppColor.accentMid)
        let position = Double(i) / Double(max(chartDays - 1, 1))
        let bubbleAlignment: Alignment = position < 0.2 ? .topLeading : (position > 0.8 ? .topTrailing : .top)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: chartDays > 30 ? 1 : 3).fill(color)
                .frame(height: height)
                .overlay(alignment: bubbleAlignment) {
                    if selected { valueBubble(day).offset(y: -34) }
                }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.15)) { selectedBar = selected ? nil : i }
        }
        .zIndex(selected ? 1 : 0)
    }

    private func valueBubble(_ day: (date: Date, value: Double, kept: Bool)) -> some View {
        let value = habit.isQuantified ? habit.formatWithUnit(day.value) : (day.kept ? "kept" : "missed")
        return VStack(alignment: .leading, spacing: 1) {
            Text(value).font(AppFont.mono(12, weight: .medium)).foregroundStyle(AppColor.inkOnAccent)
            Text(day.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                .font(AppFont.mono(9)).foregroundStyle(AppColor.inkOnAccent.opacity(0.7))
        }
        .fixedSize()
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(AppColor.accent))
        .allowsHitTesting(false)
    }

    private var calendarBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Calendar")
            MonthCalendar(month: $calendarMonth, dayStyle: calendarStyle)
            HStack(spacing: 14) {
                legend(AppColor.calendarKept, "kept")
                legend(AppColor.surface, "missed")
                legend(.clear, "rest / not due", stroke: AppColor.border)
            }
            .padding(.top, 4)
        }
    }

    private func legend(_ color: Color, _ label: String, stroke: Color? = nil) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color)
                .overlay { if let stroke { RoundedRectangle(cornerRadius: 3).stroke(stroke, lineWidth: 1) } }
                .frame(width: 12, height: 12)
            Text(label).font(AppFont.mono(10)).foregroundStyle(AppColor.inkMute)
        }
    }

    private func calendarStyle(_ date: Date) -> CalendarDayStyle {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let kept = habit.todayLog(on: date)?.completed == true
        let scheduled = habit.isScheduled(on: date)
        if cal.isDate(date, inSameDayAs: today) {
            return kept || scheduled
                ? CalendarDayStyle(fill: AppColor.accent, text: AppColor.inkOnAccent)
                : CalendarDayStyle(fill: .clear, text: AppColor.accent, stroke: AppColor.accent)
        }
        if kept { return CalendarDayStyle(fill: AppColor.calendarKept) }
        if !scheduled {
            return CalendarDayStyle(fill: .clear, text: AppColor.dimOff, stroke: AppColor.border)
        }
        if date > today { return CalendarDayStyle(fill: .clear, text: AppColor.inkDim) }
        return CalendarDayStyle()
    }

    private var archiveBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HRule()
            SecondaryButton(title: "Archive habit", color: AppColor.inkDim, borderColor: AppColor.borderStrong) {
                confirmingArchive = true
            }
            .padding(.top, 12)
            Text("For habits you're done with. They're hidden from Today and Stats but kept, so you can bring them back.")
                .font(AppFont.sans(13)).foregroundStyle(AppColor.inkMute)
                .fixedSize(horizontal: false, vertical: true)
            Button { confirmingDelete = true } label: {
                Text("Delete habit")
                    .font(AppFont.mono(12)).foregroundStyle(AppColor.inkMute)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    private func archive() {
        habit.archived = true
        habit.timerStartedAt = nil
        try? ctx.save()
        let ctx = ctx
        Task { await NotificationScheduler.reschedule(in: ctx) }
        onClose()
    }
}
