import SwiftUI
import SwiftData

struct TodayScreen: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: [SortDescriptor(\Habit.sortIndex)]) private var habits: [Habit]
    @Query private var prefsList: [AppPrefs]
    @State private var viewStyleOverride: HomeViewStyle? = nil
    var onOpenHabit: (Habit) -> Void

    private var prefs: AppPrefs? { prefsList.first }
    private var viewStyle: HomeViewStyle { viewStyleOverride ?? prefs?.defaultView ?? .list }

    private var activeHabits: [Habit] { habits.filter { !$0.archived } }

    private var completedToday: [Habit] {
        activeHabits.filter { $0.todayLog()?.completed == true }
    }
    private var unfinished: [Habit] {
        activeHabits.filter { $0.todayLog()?.completed != true }
    }
    private var percent: Int {
        guard !activeHabits.isEmpty else { return 0 }
        return Int((Double(completedToday.count) / Double(activeHabits.count)) * 100)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            segmentBar
            controlRow
            ScrollView {
                if viewStyle == .list { listBody } else { gridBody }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: dateHeader, color: AppColor.inkMute)
                    Text("Today")
                        .font(AppFont.serif(46))
                        .foregroundStyle(AppColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(percent)%")
                        .font(AppFont.mono(26))
                        .foregroundStyle(AppColor.accent)
                    Text("\(completedToday.count) / \(activeHabits.count) kept")
                        .font(AppFont.mono(11))
                        .foregroundStyle(AppColor.inkMute)
                }
            }
            .padding(.horizontal, AppMetrics.hPadding)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
    }

    private var dateHeader: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE d MMMM"
        return fmt.string(from: Date())
    }

    private var segmentBar: some View {
        // Completed first (left), then unfinished (right) — matches design
        let filled = Array(repeating: true, count: completedToday.count)
        let empty = Array(repeating: false, count: unfinished.count)
        return DayCompletionBar(cells: filled + empty)
            .padding(.horizontal, AppMetrics.hPadding)
            .padding(.bottom, 18)
    }

    private var controlRow: some View {
        HStack {
            SectionLabel(text: "\(unfinished.count) left today")
            Spacer()
            HStack(spacing: 0) {
                pillButton("List", active: viewStyle == .list) { setStyle(.list) }
                pillButton("Grid", active: viewStyle == .grid) { setStyle(.grid) }
            }
            .padding(3)
            .background(Capsule().fill(AppColor.surface))
        }
        .padding(.horizontal, AppMetrics.hPadding)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func pillButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(AppFont.mono(11, weight: .medium))
                .tracking(11 * 0.08)
                .foregroundStyle(active ? AppColor.inkOnAccent : AppColor.inkDim)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(active ? AppColor.accent : Color.clear))
        }
        .buttonStyle(.plain)
    }

    private func setStyle(_ style: HomeViewStyle) {
        viewStyleOverride = style
        if let p = prefs { p.defaultView = style; try? ctx.save() }
    }

    // MARK: List
    private var listBody: some View {
        VStack(spacing: 0) {
            ForEach(Array(unfinished.enumerated()), id: \.element.id) { idx, habit in
                if idx > 0 { HRule() } else { HRule() }
                TodayListRow(habit: habit, done: false, onTap: {
                    toggleDone(habit)
                }, onAction: {
                    onOpenHabit(habit)
                }, onQuickAdd: {
                    quickAdd(habit)
                })
            }
            if !unfinished.isEmpty { HRule() }

            if !completedToday.isEmpty {
                SectionLabel(text: "Done · \(completedToday.count)", color: AppColor.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)
                    .padding(.bottom, 4)
            }

            ForEach(completedToday, id: \.id) { habit in
                HRule()
                TodayListRow(habit: habit, done: true, onTap: {
                    toggleDone(habit)
                }, onAction: {
                    onOpenHabit(habit)
                }, onQuickAdd: {})
            }
            if !completedToday.isEmpty { HRule() }
            Spacer(minLength: 24)
        }
        .padding(.horizontal, AppMetrics.hPadding)
    }

    // MARK: Grid
    private var gridBody: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(unfinished, id: \.id) { habit in
                TodayGridTile(habit: habit, done: false) { toggleDone(habit) }
            }
            ForEach(completedToday, id: \.id) { habit in
                TodayGridTile(habit: habit, done: true) { toggleDone(habit) }
            }
        }
        .padding(.horizontal, AppMetrics.hPadding)
        .padding(.bottom, 24)
    }

    private func toggleDone(_ habit: Habit) {
        let today = Calendar.current.startOfDay(for: Date())
        if let log = habit.todayLog() {
            log.completed.toggle()
            if log.completed && habit.tracking != .done && log.value < habit.dailyGoal {
                log.value = habit.dailyGoal
            }
            if !log.completed {
                log.value = 0
            }
        } else {
            let l = HabitLog(date: today, value: habit.dailyGoal, completed: true)
            l.habit = habit
            ctx.insert(l)
        }
        try? ctx.save()
    }

    private func quickAdd(_ habit: Habit) {
        let today = Calendar.current.startOfDay(for: Date())
        let log = habit.todayLog() ?? {
            let l = HabitLog(date: today, value: 0, completed: false)
            l.habit = habit
            ctx.insert(l)
            return l
        }()
        switch habit.tracking {
        case .done:
            log.completed = true
        case .count:
            log.value += 1
            if log.value >= habit.dailyGoal { log.completed = true }
        case .time:
            log.value += 5
            if log.value >= habit.dailyGoal { log.completed = true }
        case .amount:
            log.value += max(1, habit.dailyGoal * 0.1)
            if log.value >= habit.dailyGoal { log.completed = true }
        }
        try? ctx.save()
    }
}

private struct TodayListRow: View {
    let habit: Habit
    let done: Bool
    var onTap: () -> Void
    var onAction: () -> Void
    var onQuickAdd: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Button(action: onTap) {
                CheckCircle(done: done)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name)
                    .font(AppFont.serif(done ? 19 : 22))
                    .foregroundStyle(done ? AppColor.inkDim : AppColor.ink)
                Text(subtitle)
                    .font(AppFont.mono(11))
                    .foregroundStyle(AppColor.inkMute)
                if !done && habit.tracking != .done {
                    ThinBar(progress: progress).padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailingView
        }
        .padding(.vertical, done ? 11 : 15)
    }

    private var subtitle: String {
        let value = Int(habit.todayLog()?.value ?? 0)
        let goal = Int(habit.dailyGoal)
        switch habit.tracking {
        case .done: return "Done / not done · \(habit.category.display.lowercased())"
        case .count: return "\(value) / \(goal) \(habit.unit) · \(habit.category.display.lowercased())"
        case .amount: return "\(value) / \(goal) \(habit.unit) · \(habit.category.display.lowercased())"
        case .time: return "\(value) / \(goal) \(habit.unit.isEmpty ? "min" : habit.unit)utes · \(habit.category.display.lowercased())"
        }
    }

    private var progress: Double {
        let value = habit.todayLog()?.value ?? 0
        guard habit.dailyGoal > 0 else { return 0 }
        return value / habit.dailyGoal
    }

    @ViewBuilder
    private var trailingView: some View {
        if done {
            Text(trailingText)
                .font(AppFont.mono(11))
                .foregroundStyle(AppColor.inkMute)
        } else {
            switch habit.tracking {
            case .done:
                Text("tap").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
            case .time:
                actionPill("+5", action: onQuickAdd)
            case .count:
                actionPill("+1", action: onQuickAdd)
            case .amount:
                actionPill("log", action: onAction)
            }
        }
    }

    private var trailingText: String {
        let value = Int(habit.todayLog()?.value ?? habit.dailyGoal)
        let goal = Int(habit.dailyGoal)
        switch habit.tracking {
        case .done: return "kept"
        case .count: return "\(value)/\(goal) \(habit.unit)"
        case .amount: return "\(value)/\(goal) \(habit.unit)"
        case .time: return "\(value)/\(goal) \(habit.unit.isEmpty ? "min" : habit.unit)"
        }
    }

    private func actionPill(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.mono(12))
                .foregroundStyle(AppColor.accent)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().stroke(AppColor.accentMid, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct TodayGridTile: View {
    let habit: Habit
    let done: Bool
    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(habit.name)
                    .font(AppFont.serif(21))
                    .foregroundStyle(done ? AppColor.accentSoft : AppColor.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                Button(action: onTap) { CheckCircle(done: done) }
                    .buttonStyle(.plain)
            }
            Spacer(minLength: 16)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(valueString)
                    .font(AppFont.mono(22))
                    .foregroundStyle(done ? AppColor.accentSoft : AppColor.ink)
                if !unitString.isEmpty {
                    Text(unitString)
                        .font(AppFont.mono(11))
                        .foregroundStyle(AppColor.inkMute)
                }
            }
            if habit.tracking != .done {
                ThinBar(
                    progress: (habit.todayLog()?.value ?? 0) / max(habit.dailyGoal, 1),
                    fill: done ? AppColor.accentSoft : AppColor.accent
                )
                .padding(.top, 8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppMetrics.tileRadius)
                .fill(done ? AppColor.surfaceAccent : AppColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.tileRadius)
                .stroke(done ? AppColor.borderAccent : AppColor.border, lineWidth: 1)
        )
    }

    private var valueString: String {
        let value = Int(habit.todayLog()?.value ?? 0)
        let goal = Int(habit.dailyGoal)
        switch habit.tracking {
        case .done: return done ? "kept" : "—"
        case .count, .amount, .time: return "\(value)/\(goal)"
        }
    }
    private var unitString: String {
        switch habit.tracking {
        case .done: return ""
        case .time: return habit.unit.isEmpty ? "min" : habit.unit
        default: return habit.unit
        }
    }
}
