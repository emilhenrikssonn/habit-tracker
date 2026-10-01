import SwiftUI
import SwiftData

struct TodayScreen: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: [SortDescriptor(\Habit.sortIndex)]) private var habits: [Habit]
    @Query private var prefsList: [AppPrefs]
    @State private var viewStyleOverride: HomeViewStyle? = nil
    var onOpenHabit: (Habit) -> Void
    var onAdd: () -> Void

    private var prefs: AppPrefs? { prefsList.first }
    private var viewStyle: HomeViewStyle { viewStyleOverride ?? prefs?.defaultView ?? .list }

    private var activeHabits: [Habit] { habits.filter { !$0.archived } }
    /// Only what's due today: started, not a rest day, and not already done enough times this week.
    private var dueToday: [Habit] { activeHabits.filter { $0.isDue(on: Date()) } }

    private var completedToday: [Habit] {
        dueToday.filter { $0.todayLog()?.completed == true }
    }
    private var unfinished: [Habit] {
        dueToday.filter { $0.todayLog()?.completed != true }
    }
    private var percent: Int {
        guard !dueToday.isEmpty else { return 0 }
        return Int((Double(completedToday.count) / Double(dueToday.count)) * 100)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if activeHabits.isEmpty {
                emptyState
            } else if dueToday.isEmpty {
                restState
            } else {
                segmentBar
                controlRow
                ScrollView {
                    if viewStyle == .list { listBody } else { gridBody }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var restState: some View {
        VStack(alignment: .leading, spacing: 14) {
            HRule().padding(.bottom, 16)
            Text("Nothing due today")
                .font(AppFont.serif(30))
                .foregroundStyle(AppColor.ink)
            Text("It's a rest day for all your habits. Enjoy it.")
                .font(AppFont.sans(15))
                .foregroundStyle(AppColor.inkDim)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, AppMetrics.hPadding)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            HRule().padding(.bottom, 16)
            Text("Nothing to track yet")
                .font(AppFont.serif(30))
                .foregroundStyle(AppColor.ink)
            Text("Add a habit and it shows up here every day it's due. Tap the circle to mark it done.")
                .font(AppFont.sans(15))
                .foregroundStyle(AppColor.inkDim)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: "Add your first habit", action: onAdd)
                .padding(.top, 10)
            Spacer()
        }
        .padding(.horizontal, AppMetrics.hPadding)
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
                if !dueToday.isEmpty {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(percent)%")
                            .font(AppFont.mono(26))
                            .foregroundStyle(AppColor.accent)
                        Text("\(completedToday.count) / \(dueToday.count) kept")
                            .font(AppFont.mono(11))
                            .foregroundStyle(AppColor.inkMute)
                    }
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
                }, onQuickAdd: {
                    quickAdd(habit)
                })
            }
            if !completedToday.isEmpty { HRule() }
            Spacer(minLength: 24)
        }
        .padding(.horizontal, AppMetrics.hPadding)
    }

    // MARK: Grid
    private var gridBody: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(unfinished + completedToday, id: \.id) { habit in
                TodayGridTile(
                    habit: habit,
                    done: habit.todayLog()?.completed == true,
                    onToggle: { toggleDone(habit) },
                    onOpen: { onOpenHabit(habit) },
                    onQuickAdd: { quickAdd(habit) }
                )
            }
        }
        .padding(.horizontal, AppMetrics.hPadding)
        .padding(.bottom, 24)
    }

    private func toggleDone(_ habit: Habit) {
        habit.toggleDone(in: ctx)
    }

    private func quickAdd(_ habit: Habit) {
        if habit.isQuantified { habit.add(1, in: ctx) } else { habit.toggleDone(in: ctx) }
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

            Button(action: onAction) {
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
            .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            trailingView
        }
        .padding(.vertical, done ? 11 : 15)
    }

    private var subtitle: String {
        let category = habit.categoryName.lowercased()
        guard habit.isQuantified else { return "Done / not done · \(category)" }
        let value = habit.format(habit.todayLog()?.value ?? 0)
        return "\(value) / \(habit.formatWithUnit(habit.dailyGoal)) · \(category)"
    }

    private var progress: Double {
        let value = habit.todayLog()?.value ?? 0
        guard habit.dailyGoal > 0 else { return 0 }
        return value / habit.dailyGoal
    }

    @ViewBuilder
    private var trailingView: some View {
        if habit.isQuantified {
            actionPill("+1", action: onQuickAdd)
        } else if done {
            Text("kept").font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
        } else {
            Text("tap").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
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
    var onToggle: () -> Void
    var onOpen: () -> Void
    var onQuickAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(habit.name)
                    .font(AppFont.serif(21))
                    .foregroundStyle(done ? AppColor.accentSoft : AppColor.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                Button(action: onToggle) { CheckCircle(done: done).padding(4).contentShape(Rectangle()) }
                    .buttonStyle(.plain)
            }
            Spacer(minLength: 16)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(valueString)
                    .font(AppFont.mono(22))
                    .foregroundStyle(done ? AppColor.accentSoft : AppColor.ink)
                if !habit.unitLabel.isEmpty {
                    Text(habit.unitLabel)
                        .font(AppFont.mono(11))
                        .foregroundStyle(AppColor.inkMute)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if habit.isQuantified {
                    Button(action: onQuickAdd) {
                        Text("+1")
                            .font(AppFont.mono(12))
                            .foregroundStyle(AppColor.accent)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().stroke(AppColor.accentMid, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            if habit.isQuantified {
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
        .contentShape(RoundedRectangle(cornerRadius: AppMetrics.tileRadius))
        .onTapGesture(perform: onOpen)
    }

    private var valueString: String {
        guard habit.isQuantified else { return done ? "kept" : "—" }
        return "\(habit.format(habit.todayLog()?.value ?? 0))/\(habit.format(habit.dailyGoal))"
    }
}
