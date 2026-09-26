import SwiftUI
import SwiftData

struct HabitsScreen: View {
    @Query(sort: [SortDescriptor(\Habit.sortIndex)]) private var habits: [Habit]
    var onAdd: () -> Void
    var onOpenHabit: (Habit) -> Void

    private var active: [Habit] { habits.filter { !$0.archived } }
    private var archived: [Habit] { habits.filter { $0.archived } }

    private var grouped: [(HabitCategory, [Habit])] {
        HabitCategory.allCases.compactMap { cat in
            let list = active.filter { $0.category == cat }
            return list.isEmpty ? nil : (cat, list)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            title
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    addBar
                    ForEach(grouped, id: \.0) { cat, list in
                        SectionLabel(text: cat.display, color: AppColor.inkMute)
                            .padding(.top, 24).padding(.bottom, 10)
                        ForEach(list, id: \.id) { habit in
                            HRule()
                            HabitRow(habit: habit) { onOpenHabit(habit) }
                        }
                        HRule()
                    }
                    Button {
                        // no-op stub
                    } label: {
                        HStack {
                            Text("Archived habits").font(AppFont.serif(20)).foregroundStyle(AppColor.inkDim)
                            Spacer()
                            Text("›").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
                        }
                        .padding(.vertical, 15)
                    }
                    .buttonStyle(.plain)
                    HRule()
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, AppMetrics.hPadding)
            }
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("My habits")
                .font(AppFont.serif(40))
                .foregroundStyle(AppColor.ink)
            Text("\(active.count) active · \(archived.count) archived")
                .font(AppFont.mono(11))
                .foregroundStyle(AppColor.inkMute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppMetrics.hPadding)
        .padding(.top, 20)
        .padding(.bottom, 18)
    }

    private var addBar: some View {
        Button(action: onAdd) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                    .foregroundStyle(AppColor.outline)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Text("+")
                            .font(AppFont.serif(20))
                            .foregroundStyle(AppColor.accent)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add habit").font(AppFont.serif(21)).foregroundStyle(AppColor.ink)
                    Text("Suggested or custom")
                        .font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
                }
                Spacer()
                Text("›").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct HabitRow: View {
    let habit: Habit
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(habit.name).font(AppFont.serif(21)).foregroundStyle(AppColor.ink)
                    Text(meta)
                        .font(AppFont.mono(11))
                        .foregroundStyle(AppColor.inkMute)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(completion)% ›")
                    .font(AppFont.mono(12))
                    .foregroundStyle(completion >= 80 ? AppColor.accent : AppColor.inkDim)
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    private var meta: String {
        let track: String
        switch habit.tracking {
        case .done: track = "Done · every day"
        case .count: track = "Count · \(Int(habit.dailyGoal)) \(habit.unit)/day · \(habit.scheduleSummary)"
        case .amount: track = "Amount · \(Int(habit.dailyGoal)) \(habit.unit)/day · \(habit.scheduleSummary)"
        case .time: track = "Time · \(Int(habit.dailyGoal)) \(habit.unit)/day · \(habit.scheduleSummary)"
        }
        return track
    }
    private var completion: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let from = cal.date(byAdding: .day, value: -29, to: today) else { return 0 }
        let logs = habit.logs.filter { $0.date >= from && $0.date <= today }
        let complete = logs.filter { $0.completed }.count
        return logs.isEmpty ? 0 : Int(Double(complete) / Double(logs.count) * 100)
    }
}
