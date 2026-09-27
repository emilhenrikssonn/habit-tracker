import SwiftUI
import SwiftData

struct HabitSetupScreen: View {
    @Environment(\.modelContext) private var ctx
    var prefilled: CatalogueEntry?
    var editing: Habit?
    var onClose: () -> Void

    @State private var name: String
    @State private var category: HabitCategory
    @State private var type: HabitType
    @State private var tracking: TrackingType
    @State private var unit: String
    @State private var goal: Double
    @State private var repeatMode: RepeatMode = .daily
    @State private var weekdays: Set<Int> = [1,2,3,4,5,6,7]
    @State private var timesPerWeek: Int = 4
    @State private var reminder: String? = "08:00"

    init(prefilled: CatalogueEntry?, onClose: @escaping () -> Void) {
        self.prefilled = prefilled
        self.onClose = onClose
        _name = State(initialValue: prefilled?.name ?? "New habit")
        _category = State(initialValue: prefilled?.category ?? .health)
        _type = State(initialValue: prefilled?.type ?? .build)
        _tracking = State(initialValue: prefilled?.tracking ?? .done)
        _unit = State(initialValue: prefilled?.unit ?? "")
        _goal = State(initialValue: prefilled?.goal ?? 1)
    }

    init(editing habit: Habit, onClose: @escaping () -> Void) {
        self.editing = habit
        self.onClose = onClose
        _name = State(initialValue: habit.name)
        _category = State(initialValue: habit.category)
        _type = State(initialValue: habit.type)
        _tracking = State(initialValue: habit.tracking)
        _unit = State(initialValue: habit.unit)
        _goal = State(initialValue: habit.dailyGoal)
        _repeatMode = State(initialValue: habit.repeatMode)
        _weekdays = State(initialValue: Set(habit.weekdays))
        _timesPerWeek = State(initialValue: habit.timesPerWeek)
        _reminder = State(initialValue: habit.reminder)
    }

    var body: some View {
        ScreenScaffold {
            VStack(spacing: 0) {
                headerRow
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        titleBlock
                        trackingBlock
                        goalBlock
                        repeatBlock
                        detailRows
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, AppMetrics.hPadding)
                }
                CancelSaveBar(cancelText: "Cancel", saveText: editing == nil ? "Save habit" : "Save changes",
                              onCancel: onClose, onSave: save)
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Button(action: onClose) {
                Text("‹ back").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
            }.buttonStyle(.plain)
            Spacer()
            SectionLabel(text: editing == nil ? "how to track it" : "edit habit")
        }
        .padding(.horizontal, AppMetrics.hPadding)
        .padding(.top, 18)
        .padding(.bottom, 20)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Habit name", text: $name)
                .font(AppFont.serif(40))
                .foregroundStyle(AppColor.ink)
                .submitLabel(.done)
            HStack(spacing: 8) {
                CategoryChip(title: category.display, isActive: true) {
                    let all = HabitCategory.allCases
                    category = all[(all.firstIndex(of: category)! + 1) % all.count]
                }
                CategoryChip(title: type.display, isActive: false) {
                    type = type == .build ? .quit : .build
                }
            }
        }
    }

    private var trackingBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Tracking")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(TrackingType.allCases) { t in
                    trackingTile(t)
                }
            }
            Text(tracking.hint)
                .font(AppFont.sans(13))
                .foregroundStyle(AppColor.inkMute)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func trackingTile(_ t: TrackingType) -> some View {
        Button {
            tracking = t
            if t == .done { goal = 1 }
            if t == .time && unit.isEmpty { unit = "min" }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(t.display).font(AppFont.serif(21))
                    .foregroundStyle(tracking == t ? AppColor.ink : AppColor.inkDim)
                Text(t.caption).font(AppFont.mono(11))
                    .foregroundStyle(AppColor.inkMute)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppMetrics.inputRadius)
                    .fill(tracking == t ? AppColor.surfaceAccent : AppColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.inputRadius)
                    .stroke(tracking == t ? AppColor.accentMid : AppColor.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var goalBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Daily goal")
            HStack(spacing: 10) {
                Text("\(Int(goal))")
                    .font(AppFont.mono(24))
                    .foregroundStyle(AppColor.ink)
                if tracking == .done {
                    Text("time a day").font(AppFont.mono(12)).foregroundStyle(AppColor.inkMute)
                } else {
                    TextField("unit", text: $unit)
                        .font(AppFont.mono(12))
                        .foregroundStyle(AppColor.accent)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .frame(maxWidth: 90)
                }
                Spacer()
                stepper(sign: "−") { if goal > 1 { goal -= goalStep } }
                stepper(sign: "+", accent: true) { goal += goalStep }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: AppMetrics.inputRadius).fill(AppColor.surface))
            .disabled(tracking == .done)
            .opacity(tracking == .done ? 0.5 : 1)
            if tracking != .done {
                Text("You'll log this habit in \(unitPlaceholder) — tap the unit to change it.")
                    .font(AppFont.sans(13))
                    .foregroundStyle(AppColor.inkMute)
            }
        }
    }

    private var goalStep: Double { goal > 20 ? 5 : 1 }

    private var unitPlaceholder: String {
        let u = unit.trimmingCharacters(in: .whitespaces)
        return u.isEmpty ? (tracking == .time ? "min" : "units") : u
    }

    private func stepper(sign: String, accent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(sign)
                .font(AppFont.serif(22))
                .foregroundStyle(accent ? AppColor.accent : AppColor.inkDim)
                .frame(width: 32, height: 32)
                .background(Circle().stroke(accent ? AppColor.accentMid : AppColor.borderStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var repeatBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Repeat")
            HStack(spacing: 8) {
                ForEach(RepeatMode.allCases) { m in
                    CategoryChip(title: m.display, isActive: repeatMode == m) { repeatMode = m }
                }
            }
            switch repeatMode {
            case .daily:
                Text("Every day of the week, all year.")
                    .font(AppFont.sans(13))
                    .foregroundStyle(AppColor.inkMute)
            case .days:
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { i in
                        DayPill(letter: Habit.dayLetter(i), isActive: weekdays.contains(i)) {
                            if weekdays.contains(i) { weekdays.remove(i) } else { weekdays.insert(i) }
                        }
                    }
                }
            case .weekly:
                HStack(spacing: 10) {
                    Text("\(timesPerWeek) × per week")
                        .font(AppFont.mono(20)).foregroundStyle(AppColor.ink)
                    Spacer()
                    stepper(sign: "−") { if timesPerWeek > 1 { timesPerWeek -= 1 } }
                    stepper(sign: "+", accent: true) { if timesPerWeek < 7 { timesPerWeek += 1 } }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: AppMetrics.inputRadius).fill(AppColor.surface))
            case .dates:
                DisclosureRow(title: "1 · 8 · 15 · 22 of the month",
                              titleFont: AppFont.serif(19),
                              trailing: "pick")
            }
        }
    }

    private var detailRows: some View {
        VStack(spacing: 0) {
            HRule()
            DisclosureRow(title: "Active period",
                          titleFont: AppFont.serif(20),
                          trailing: "26 Sep – 31 Dec")
            HRule()
            DisclosureRow(title: "Time of day",
                          titleFont: AppFont.serif(20),
                          trailing: "Morning · pause wk 29–31")
            HRule()
            DisclosureRow(title: "Reminder",
                          titleFont: AppFont.serif(20),
                          trailing: reminder ?? "off",
                          trailingColor: reminder == nil ? AppColor.inkDim : AppColor.accent) {
                reminder = reminder == nil ? "08:00" : nil
            }
            HRule()
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespaces)
        let h = editing ?? Habit(name: "", category: category, sortIndex: 100)
        h.name = trimmedName.isEmpty ? "New habit" : trimmedName
        h.category = category
        h.type = type
        h.tracking = tracking
        h.unit = tracking == .done ? "" : trimmedUnit
        h.dailyGoal = tracking == .done ? 1 : max(goal, 1)
        h.repeatMode = repeatMode
        h.weekdays = Array(weekdays).sorted()
        h.timesPerWeek = timesPerWeek
        h.reminder = reminder
        if editing == nil { ctx.insert(h) }
        // Today's completion follows the (possibly new) goal.
        if let log = h.todayLog(), h.isQuantified {
            log.completed = log.value >= h.dailyGoal
        }
        try? ctx.save()
        onClose()
    }
}
