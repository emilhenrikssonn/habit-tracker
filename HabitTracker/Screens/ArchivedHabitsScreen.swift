import SwiftUI
import SwiftData

/// Habits you've stopped doing. They keep their history but stay out of Today, Stats and reminders.
struct ArchivedHabitsScreen: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Habit> { $0.archived }, sort: [SortDescriptor(\Habit.name)])
    private var archived: [Habit]
    var onClose: () -> Void

    @State private var deleting: Habit? = nil

    var body: some View {
        ScreenScaffold {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button(action: onClose) {
                        Text("‹ back").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
                    }.buttonStyle(.plain)
                    Spacer()
                    SectionLabel(text: "habits")
                }
                .padding(.top, 18).padding(.bottom, 20)

                Text("Archived").font(AppFont.serif(40)).foregroundStyle(AppColor.ink)
                Text("Hidden from Today and Stats. Reactivate one to pick it back up with its history.")
                    .font(AppFont.sans(14)).foregroundStyle(AppColor.inkDim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6).padding(.bottom, 18)

                ScrollView {
                    VStack(spacing: 0) {
                        if archived.isEmpty {
                            HRule()
                            Text("Nothing archived. You can archive a habit from its page when you no longer want to track it.")
                                .font(AppFont.sans(14)).foregroundStyle(AppColor.inkMute)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 18)
                        }
                        ForEach(archived) { habit in
                            HRule()
                            row(habit)
                        }
                        HRule()
                    }
                }
            }
            .padding(.horizontal, AppMetrics.hPadding)
        }
        .confirmationDialog("Delete \(deleting?.name ?? "habit")?",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("Delete for good", role: .destructive) {
                if let habit = deleting { ctx.delete(habit); try? ctx.save() }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("Its whole history is removed from this iPhone. This can't be undone.")
        }
    }

    private func row(_ habit: Habit) -> some View {
        let kept = habit.logs.filter(\.completed).count
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name).font(AppFont.serif(21)).foregroundStyle(AppColor.inkDim)
                Text("\(habit.categoryName) · kept \(kept) \(kept == 1 ? "day" : "days")")
                    .font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
            }
            Spacer()
            Button { deleting = habit } label: {
                Text("Delete").font(AppFont.mono(12)).foregroundStyle(AppColor.inkMute)
            }
            .buttonStyle(.plain)
            Button { reactivate(habit) } label: {
                Text("Reactivate")
                    .font(AppFont.mono(12)).foregroundStyle(AppColor.accent)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().stroke(AppColor.accentMid, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 14)
    }

    private func reactivate(_ habit: Habit) {
        habit.archived = false
        try? ctx.save()
        let ctx = ctx
        Task { await NotificationScheduler.reschedule(in: ctx) }
    }
}
