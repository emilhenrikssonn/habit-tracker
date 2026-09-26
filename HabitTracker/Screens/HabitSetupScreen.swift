import SwiftUI
import SwiftData

struct HabitSetupScreen: View {
    @Environment(\.modelContext) private var ctx
    var prefilled: CatalogueEntry?
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
                CancelSaveBar(cancelText: "Cancel", saveText: "Save habit",
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
            SectionLabel(text: "how to track it")
        }
        .padding(.horizontal, AppMetrics.hPadding)
        .padding(.top, 18)
        .padding(.bottom, 20)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(name)
                .font(AppFont.serif(40))
                .foregroundStyle(AppColor.ink)
            HStack(spacing: 8) {
                CategoryChip(title: category.display, isActive: true) {}
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
                Text(unit.isEmpty ? tracking.caption : unit)
                    .font(AppFont.mono(12))
                    .foregroundStyle(AppColor.inkMute)
                Spacer()
                stepper(sign: "−") { if goal > 1 { goal -= 1 } }
                stepper(sign: "+", accent: true) { goal += 1 }
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
                reminder = reminder == nil ? "08:00" : nil
            }
            HRule()
        }
    }

    private func save() {
        let h = Habit(
            name: name,
            category: category,
            type: type,
            tracking: tracking,
            unit: unit,
            dailyGoal: goal,
            repeatMode: repeatMode,
            weekdays: Array(weekdays).sorted(),
            timeOfDay: "Anytime",
            reminder: reminder,
            sortIndex: 100
        )
        ctx.insert(h)
        try? ctx.save()
        onClose()
    }
}
