import SwiftUI
import SwiftData

struct HabitDetailScreen: View {
    @Environment(\.modelContext) private var ctx
    let habit: Habit
    var onClose: () -> Void

    @State private var editing = false
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
                        chartBlock
                        calendarBlock
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, AppMetrics.hPadding)
                }
            }
        }
        .sheet(isPresented: $editing) {
            HabitSetupScreen(editing: habit, onClose: { editing = false })
        }
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
                MetaChip(text: "LOG")
            }
            if habit.isQuantified {
                ThinBar(progress: value / max(habit.dailyGoal, 1), height: 6, track: AppColor.border, fill: AppColor.accent)
                HStack(spacing: 10) {
                    actionPill("−1") { habit.add(-1, in: ctx) }
                        .disabled(value <= 0)
                        .opacity(value <= 0 ? 0.4 : 1)
                    ForEach(habit.logSteps, id: \.self) { step in
                        actionPill("+\(habit.format(step))") { habit.add(step, in: ctx) }
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

    /// 04:12, or 1:04:12 past an hour.
    private static func clock(_ t: TimeInterval) -> String {
        let s = Int(t)
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
            : String(format: "%02d:%02d", s / 60, s % 60)
    }

    private func actionPill(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.mono(12)).foregroundStyle(AppColor.accent)
                .lineLimit(1)
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
            SectionLabel(text: Date().formatted(.dateTime.month(.wide)))
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
