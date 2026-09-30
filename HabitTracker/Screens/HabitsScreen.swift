import SwiftUI
import SwiftData

struct HabitsScreen: View {
    @Query(sort: [SortDescriptor(\Habit.sortIndex)]) private var habits: [Habit]
    var onAdd: () -> Void
    var onOpenHabit: (Habit) -> Void

    @State private var showingArchived = false

    private var active: [Habit] { habits.filter { !$0.archived } }
    private var archived: [Habit] { habits.filter { $0.archived } }

    private var grouped: [(String, [Habit])] {
        let builtIn = HabitCategory.allCases.map(\.rawValue)
        let custom = Set(active.map(\.categoryRaw)).subtracting(builtIn).sorted()
        return (builtIn + custom).compactMap { raw in
            let list = active.filter { $0.categoryRaw == raw }
            return list.isEmpty ? nil : (raw, list)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            title
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    addBar
                    ForEach(grouped, id: \.0) { cat, list in
                        SectionLabel(text: Habit.categoryName(for: cat), color: AppColor.inkMute)
                            .padding(.top, 24).padding(.bottom, 10)
                        ForEach(list, id: \.id) { habit in
                            HRule()
                            HabitRow(habit: habit) { onOpenHabit(habit) }
                        }
                        HRule()
                    }
                    Button {
                        showingArchived = true
                    } label: {
                        HStack {
                            Text("Archived habits").font(AppFont.serif(20)).foregroundStyle(AppColor.inkDim)
                            Spacer()
                            Text(archived.isEmpty ? "›" : "\(archived.count) ›").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
                        }
                        .padding(.vertical, 15)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    HRule()
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, AppMetrics.hPadding)
            }
        }
        .sheet(isPresented: $showingArchived) {
            ArchivedHabitsScreen(onClose: { showingArchived = false })
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
                Text(notStarted ? "– ›" : "\(completion)% ›")
                    .font(AppFont.mono(12))
                    .foregroundStyle(!notStarted && completion >= 80 ? AppColor.accent : AppColor.inkDim)
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    private var meta: String {
        let goal = habit.isQuantified ? "\(habit.tracking.display) · \(habit.formatWithUnit(habit.dailyGoal))/day" : "Done"
        let start = Calendar.current.startOfDay(for: habit.activeStart)
        if start > Calendar.current.startOfDay(for: Date()) {
            return "\(goal) · starts \(start.formatted(.dateTime.day().month(.abbreviated)))"
        }
        return "\(goal) · \(habit.scheduleSummary)"
    }
    private var notStarted: Bool {
        Calendar.current.startOfDay(for: habit.activeStart) > Calendar.current.startOfDay(for: Date())
    }
    /// Share of due days kept over the last 30 days.
    private var completion: Int { habit.stats().rate }
}
