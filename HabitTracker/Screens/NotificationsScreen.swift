import SwiftUI
import SwiftData
import UserNotifications

struct NotificationsScreen: View {
    @Query private var prefsList: [AppPrefs]
    @Environment(\.scenePhase) private var scenePhase
    var onClose: () -> Void

    @State private var status: UNAuthorizationStatus = .notDetermined

    var body: some View {
        ScreenScaffold {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Notifications")
                            .font(AppFont.serif(36)).foregroundStyle(AppColor.ink)
                        if status == .denied { deniedCard }
                        if let prefs = prefsList.first {
                            NotificationOptions(prefs: prefs, asksPermission: true, onPermissionChange: refreshStatus)
                        }
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, AppMetrics.hPadding)
                }
            }
        }
        .task { await refreshStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refreshStatus() } }
        }
    }

    private var header: some View {
        HStack {
            Button(action: onClose) {
                Text("‹ back").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
            }.buttonStyle(.plain)
            Spacer()
            SectionLabel(text: "settings")
        }
        .padding(.horizontal, AppMetrics.hPadding).padding(.top, 18).padding(.bottom, 20)
    }

    private var deniedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notifications are turned off for Habits in iOS Settings, so none of these will arrive.")
                .font(AppFont.sans(14)).foregroundStyle(AppColor.accentSoft)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton(title: "Open iOS Settings") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).fill(AppColor.surfaceAccent))
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).stroke(AppColor.borderAccent, lineWidth: 1))
    }

    private func refreshStatus() async {
        status = await NotificationScheduler.status()
    }
}

/// Every notification choice, used both in onboarding and in Settings.
struct NotificationOptions: View {
    @Environment(\.modelContext) private var ctx
    @Query private var habits: [Habit]
    @Bindable var prefs: AppPrefs
    /// Onboarding passes the time to give the habits it adds; elsewhere reminders are set per habit.
    var habitReminderTime: Binding<String>? = nil
    /// Settings asks for permission as soon as something is switched on; onboarding asks with its own button.
    var asksPermission: Bool = false
    var onPermissionChange: () async -> Void = {}

    private var remindersSet: Int { habits.filter { !$0.archived && $0.reminder != nil }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            group("Your habits") {
                ToggleRow(title: "Habit reminders", subtitle: habitRemindersSubtitle,
                          isOn: bind(\.habitRemindersEnabled))
                if prefs.habitRemindersEnabled, let habitReminderTime {
                    HRule()
                    TimeRow(title: "Remind me at", time: habitReminderTime)
                }
            }

            group("Daily") {
                ToggleRow(title: "Morning plan", subtitle: "What's due today",
                          isOn: bind(\.morningPlanEnabled))
                if prefs.morningPlanEnabled {
                    HRule()
                    TimeRow(title: "Send at", time: bind(\.morningPlanTime))
                }
                HRule()
                ToggleRow(title: "Evening check-in", subtitle: "Only if something is still open",
                          isOn: bind(\.eveningCheckinEnabled))
                if prefs.eveningCheckinEnabled {
                    HRule()
                    TimeRow(title: "Send at", time: bind(\.eveningCheckinTime))
                }
            }

            group("Streaks") {
                ToggleRow(title: "Streak rescue", subtitle: "Warns before a streak breaks",
                          isOn: bind(\.streakRescueEnabled))
                if prefs.streakRescueEnabled {
                    HRule()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Protect streaks of").font(AppFont.serif(20)).foregroundStyle(AppColor.ink)
                        HStack(spacing: 8) {
                            ForEach([3, 7, 14, 30], id: \.self) { days in
                                CategoryChip(title: "\(days)+", isActive: prefs.streakRescueMinDays == days) {
                                    bind(\.streakRescueMinDays).wrappedValue = days
                                }
                            }
                            Text("days").font(AppFont.mono(12)).foregroundStyle(AppColor.inkMute)
                        }
                    }
                    .padding(.vertical, 14)
                    HRule()
                    TimeRow(title: "Alert at", time: bind(\.streakRescueAlertTime))
                }
            }

            group("Weekly") {
                ToggleRow(title: "Weekly report",
                          subtitle: prefs.weeklyReportEnabled
                            ? "\(ClockTime.weekdayName(prefs.weeklyReportWeekday))s at \(NotificationScheduler.weeklyReportTime)"
                            : "A look back at your week",
                          isOn: bind(\.weeklyReportEnabled))
                if prefs.weeklyReportEnabled {
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { day in
                            DayPill(letter: Habit.dayLetter(day), isActive: prefs.weeklyReportWeekday == day) {
                                bind(\.weeklyReportWeekday).wrappedValue = day
                            }
                        }
                    }
                    .padding(.bottom, 14)
                }
            }
        }
    }

    private var habitRemindersSubtitle: String {
        if habitReminderTime != nil { return "A nudge for each habit you add" }
        switch remindersSet {
        case 0: return "Set a time on a habit in Habits"
        case 1: return "1 habit has a reminder"
        default: return "\(remindersSet) habits have a reminder"
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: title).padding(.bottom, 8)
            HRule()
            content()
            HRule()
        }
    }

    /// A binding that saves and reschedules notifications whenever the value changes.
    private func bind<T>(_ keyPath: ReferenceWritableKeyPath<AppPrefs, T>) -> Binding<T> {
        Binding(
            get: { prefs[keyPath: keyPath] },
            set: { newValue in
                withAnimation(.easeOut(duration: 0.15)) { prefs[keyPath: keyPath] = newValue }
                try? ctx.save()
                Task {
                    if asksPermission, prefs.enabledNotificationCount > 0 {
                        await NotificationScheduler.requestPermission()
                        await onPermissionChange()
                    }
                    await NotificationScheduler.reschedule(in: ctx)
                }
            }
        )
    }
}
