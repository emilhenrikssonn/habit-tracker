import SwiftUI
import SwiftData

struct HabitSetupScreen: View {
    @Environment(\.modelContext) private var ctx
    var prefilled: CatalogueEntry?
    var editing: Habit?
    var onClose: () -> Void

    @State private var name: String
    @State private var categoryRaw: String
    @State private var type: HabitType
    @State private var tracking: TrackingType
    // Goal and unit are kept per tracking type, so switching back and forth doesn't lose them.
    @State private var amountUnit: String
    @State private var amountGoal: Double
    @State private var timeGoal: Double
    @State private var repeatMode: RepeatMode = .daily
    @State private var weekdays: Set<Int> = [1,2,3,4,5,6,7]
    @State private var timesPerWeek: Int = 4
    @State private var reminder: String? = nil
    @State private var pickingCategory = false
    @State private var pickingReminder = false

    init(prefilled: CatalogueEntry?, onClose: @escaping () -> Void) {
        self.prefilled = prefilled
        self.onClose = onClose
        let tracking = prefilled?.tracking ?? .done
        _name = State(initialValue: prefilled?.name ?? "New habit")
        _categoryRaw = State(initialValue: (prefilled?.category ?? .health).rawValue)
        _type = State(initialValue: prefilled?.type ?? .build)
        _tracking = State(initialValue: tracking)
        _amountUnit = State(initialValue: tracking == .amount ? prefilled?.unit ?? "" : "")
        _amountGoal = State(initialValue: tracking == .amount ? prefilled?.goal ?? 1 : 1)
        _timeGoal = State(initialValue: tracking == .time ? prefilled?.goal ?? 30 : 30)
    }

    init(editing habit: Habit, onClose: @escaping () -> Void) {
        self.editing = habit
        self.onClose = onClose
        _name = State(initialValue: habit.name)
        _categoryRaw = State(initialValue: habit.categoryRaw)
        _type = State(initialValue: habit.type)
        _tracking = State(initialValue: habit.tracking)
        _amountUnit = State(initialValue: habit.tracking == .amount ? habit.unit : "")
        _amountGoal = State(initialValue: habit.tracking == .amount ? habit.dailyGoal : 1)
        _timeGoal = State(initialValue: habit.tracking == .time ? habit.dailyGoal : 30)
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
        .sheet(isPresented: $pickingReminder) {
            TimePickerSheet(title: "Reminder", initial: reminder ?? "08:00",
                            onSave: { reminder = $0 },
                            onRemove: reminder == nil ? nil : { reminder = nil },
                            onClose: { pickingReminder = false })
        }
        .sheet(isPresented: $pickingCategory) {
            CategoryPickerSheet(selection: $categoryRaw, onClose: { pickingCategory = false })
                .presentationDetents([.medium, .large])
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
        VStack(alignment: .leading, spacing: 12) {
            TextField("Habit name", text: $name)
                .font(AppFont.serif(40))
                .foregroundStyle(AppColor.ink)
                .submitLabel(.done)
            HStack(spacing: 10) {
                CategoryChip(title: Habit.categoryName(for: categoryRaw), isActive: true) { pickingCategory = true }
                Button { pickingCategory = true } label: {
                    Text("Change category ›").font(AppFont.mono(12)).foregroundStyle(AppColor.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var trackingBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "Tracking")
                Spacer()
                HStack(spacing: 6) {
                    CategoryChip(title: HabitType.build.display, isActive: type == .build) { type = .build }
                    CategoryChip(title: HabitType.quit.display, isActive: type == .quit) { type = .quit }
                }
            }
            HStack(spacing: 10) {
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
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(t.display).font(AppFont.serif(20))
                    .foregroundStyle(tracking == t ? AppColor.ink : AppColor.inkDim)
                Text(t.caption).font(AppFont.mono(10))
                    .foregroundStyle(AppColor.inkMute)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
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

    @ViewBuilder
    private var goalBlock: some View {
        switch tracking {
        case .done:
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Daily goal")
                Text("Mark it done once a day.")
                    .font(AppFont.sans(13)).foregroundStyle(AppColor.inkMute)
            }
        case .time:
            goalEditor(goal: $timeGoal, step: timeGoal >= 30 ? 5 : 1) {
                Text("min").font(AppFont.mono(12)).foregroundStyle(AppColor.inkMute)
            }
        case .amount:
            VStack(alignment: .leading, spacing: 10) {
                goalEditor(goal: $amountGoal, step: amountGoal >= 20 ? 5 : 1) {
                    TextField("unit", text: $amountUnit, prompt: Text("unit").foregroundStyle(AppColor.inkDim))
                        .font(AppFont.mono(12))
                        .foregroundStyle(AppColor.accent)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .frame(maxWidth: 110)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).stroke(AppColor.accentMid, lineWidth: 1))
                }
                Text("What do you count? E.g. pages, glasses, km, push-ups.")
                    .font(AppFont.sans(13)).foregroundStyle(AppColor.inkMute)
            }
        }
    }

    private func goalEditor<Unit: View>(goal: Binding<Double>, step: Double, @ViewBuilder unit: () -> Unit) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Daily goal")
            HStack(spacing: 10) {
                Text("\(Int(goal.wrappedValue))")
                    .font(AppFont.mono(24))
                    .foregroundStyle(AppColor.ink)
                unit()
                Spacer()
                stepper(sign: "−") { goal.wrappedValue = max(1, goal.wrappedValue - step) }
                stepper(sign: "+", accent: true) { goal.wrappedValue += step }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: AppMetrics.inputRadius).fill(AppColor.surface))
        }
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
                pickingReminder = true
            }
            HRule()
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let h = editing ?? Habit(name: "", category: .health, sortIndex: 100)
        h.name = trimmedName.isEmpty ? "New habit" : trimmedName
        h.categoryRaw = categoryRaw
        h.type = type
        h.tracking = tracking
        switch tracking {
        case .done:
            h.unit = ""; h.dailyGoal = 1
        case .time:
            h.unit = "min"; h.dailyGoal = timeGoal
        case .amount:
            h.unit = amountUnit.trimmingCharacters(in: .whitespaces); h.dailyGoal = amountGoal
        }
        h.repeatMode = repeatMode
        h.weekdays = Array(weekdays).sorted()
        h.timesPerWeek = timesPerWeek
        h.reminder = reminder
        if editing == nil { ctx.insert(h) }
        // Today's completion follows the (possibly new) goal.
        if let log = h.todayLog(), h.isQuantified {
            log.completed = log.value >= h.dailyGoal
        }
        if reminder != nil, let prefs = try? ctx.fetch(FetchDescriptor<AppPrefs>()).first {
            // Setting a time on a habit means wanting its reminders.
            prefs.habitRemindersEnabled = true
        }
        try? ctx.save()
        let ctx = ctx
        let wantsReminder = reminder != nil
        Task {
            if wantsReminder { await NotificationScheduler.requestPermission() }
            await NotificationScheduler.reschedule(in: ctx)
        }
        onClose()
    }
}

/// Built-in categories, custom ones you've created, and a field to add a new one.
private struct CategoryPickerSheet: View {
    @Environment(\.modelContext) private var ctx
    @Query private var prefsList: [AppPrefs]
    @Query private var habits: [Habit]
    @Binding var selection: String
    var onClose: () -> Void
    @State private var newName = ""

    private var categories: [String] {
        let builtIn = HabitCategory.allCases.map(\.rawValue)
        let custom = Set((prefsList.first?.customCategories ?? []) + habits.map(\.categoryRaw))
            .subtracting(builtIn)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return builtIn + custom
    }

    var body: some View {
        ScreenScaffold {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Category").font(AppFont.serif(32)).foregroundStyle(AppColor.ink)
                    Spacer()
                    Button(action: onClose) {
                        Text("Done").font(AppFont.mono(12)).foregroundStyle(AppColor.accent)
                    }.buttonStyle(.plain)
                }
                .padding(.top, 22).padding(.bottom, 14)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(categories, id: \.self) { raw in
                            HRule()
                            Button {
                                selection = raw
                                onClose()
                            } label: {
                                HStack {
                                    Text(Habit.categoryName(for: raw))
                                        .font(AppFont.serif(21))
                                        .foregroundStyle(selection == raw ? AppColor.ink : AppColor.inkDim)
                                    Spacer()
                                    if selection == raw {
                                        Image(systemName: "checkmark").foregroundStyle(AppColor.accent)
                                    }
                                }
                                .padding(.vertical, 13)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        HRule()
                        HStack(spacing: 10) {
                            TextField("", text: $newName, prompt: Text("New category").foregroundStyle(AppColor.inkDim))
                                .font(AppFont.serif(21))
                                .foregroundStyle(AppColor.ink)
                                .submitLabel(.done)
                                .onSubmit(addCategory)
                            Button(action: addCategory) {
                                Text("Add")
                                    .font(AppFont.mono(12)).foregroundStyle(AppColor.inkOnAccent)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(Capsule().fill(AppColor.accent))
                            }
                            .buttonStyle(.plain)
                            .disabled(trimmedNew.isEmpty)
                            .opacity(trimmedNew.isEmpty ? 0.4 : 1)
                        }
                        .padding(.vertical, 13)
                        HRule()
                    }
                }
            }
            .padding(.horizontal, AppMetrics.hPadding)
        }
    }

    private var trimmedNew: String { newName.trimmingCharacters(in: .whitespaces) }

    private func addCategory() {
        let name = trimmedNew
        guard !name.isEmpty else { return }
        // Reuse a built-in or existing category if the name matches one.
        if let existing = categories.first(where: { Habit.categoryName(for: $0).caseInsensitiveCompare(name) == .orderedSame }) {
            selection = existing
        } else {
            let prefs = prefsList.first ?? { let p = AppPrefs(); ctx.insert(p); return p }()
            prefs.customCategories.append(name)
            try? ctx.save()
            selection = name
        }
        newName = ""
        onClose()
    }
}
