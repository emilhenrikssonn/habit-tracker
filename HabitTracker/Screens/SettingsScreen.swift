import SwiftUI
import SwiftData
import UserNotifications

struct SettingsScreen: View {
    @Query private var prefsList: [AppPrefs]
    @Query(filter: #Predicate<HabitLog> { $0.completed }) private var keptLogs: [HabitLog]
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var scenePhase
    var onOpenNotifications: () -> Void

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var editingName = false
    @State private var nameDraft = ""
    @State private var exportFile: ExportFile? = nil
    @AppStorage("weekStart") private var weekStart = 1

    private var prefs: AppPrefs {
        if let p = prefsList.first { return p }
        let p = AppPrefs()
        ctx.insert(p)
        try? ctx.save()
        return p
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBlock
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    profileCard
                        .padding(.top, 6)
                        .padding(.bottom, 24)

                    SectionLabel(text: "Reminders")
                    HRule().padding(.top, 8)
                    DisclosureRow(title: "Notifications", trailing: notificationsSummary,
                                  trailingColor: notificationsOn ? AppColor.accent : AppColor.inkDim) {
                        onOpenNotifications()
                    }
                    HRule()
                    DisclosureRow(title: "Streak rescue",
                                  trailing: prefs.streakRescueEnabled && notificationsOn
                                    ? "\(prefs.streakRescueMinDays)+ days · \(prefs.streakRescueAlertTime)"
                                    : "off") {
                        onOpenNotifications()
                    }
                    HRule()

                    SectionLabel(text: "App").padding(.top, 24)
                    HRule().padding(.top, 8)
                    DisclosureRow(title: "Default view", trailing: prefs.defaultView == .list ? "List" : "Grid",
                                  subtitle: "How Today opens", showChevron: false) {
                        prefs.defaultView = prefs.defaultView == .list ? .grid : .list
                        try? ctx.save()
                    }
                    HRule()
                    DisclosureRow(title: "Week starts", trailing: weekStart == 7 ? "Sunday" : "Monday",
                                  subtitle: "Calendars, weekly goals and stats", showChevron: false) {
                        weekStart = weekStart == 7 ? 1 : 7
                    }
                    HRule()
                    DisclosureRow(title: "Export data", trailing: "CSV",
                                  subtitle: "Every habit and log, as a spreadsheet") {
                        exportFile = DataExport.csvFile(in: ctx).map(ExportFile.init)
                    }
                    HRule()
                    Text("Tap Default view or Week starts to switch.")
                        .font(AppFont.mono(10)).foregroundStyle(AppColor.inkMute)
                        .padding(.top, 10)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, AppMetrics.hPadding)
            }
        }
        .task { notificationStatus = await NotificationScheduler.status() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { notificationStatus = await NotificationScheduler.status() } }
        }
        .sheet(item: $exportFile) { file in
            ShareSheet(items: [file.url])
        }
        .alert("Your name", isPresented: $editingName) {
            TextField("Name", text: $nameDraft)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = nameDraft.trimmingCharacters(in: .whitespaces)
                prefs.displayName = trimmed.isEmpty ? "You" : trimmed
                try? ctx.save()
            }
        }
    }

    private var notificationsOn: Bool {
        NotificationScheduler.isAllowed(notificationStatus) && prefs.enabledNotificationCount > 0
    }

    private var notificationsSummary: String {
        if notificationStatus == .denied { return "off in iOS" }
        return notificationsOn ? "\(prefs.enabledNotificationCount) on" : "off"
    }

    private var daysTracked: Int {
        let cal = Calendar.current
        return Set(keptLogs.map { cal.startOfDay(for: $0.date) }).count
    }

    private var titleBlock: some View {
        Text("Settings")
            .font(AppFont.serif(40)).foregroundStyle(AppColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppMetrics.hPadding)
            .padding(.top, 20).padding(.bottom, 12)
    }

    private var profileCard: some View {
        Button {
            nameDraft = prefs.displayName == "You" ? "" : prefs.displayName
            editingName = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(AppColor.accentMid).frame(width: 46, height: 46)
                    Text(String(prefs.displayName.prefix(1)))
                        .font(AppFont.serif(22))
                        .foregroundStyle(AppColor.accentSoftLight)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(prefs.displayName).font(AppFont.serif(22)).foregroundStyle(AppColor.ink)
                    Text(daysTracked == 0 ? "Nothing tracked yet" : daysTracked == 1 ? "1 day tracked" : "\(daysTracked) days tracked")
                        .font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
                }
                Spacer()
                Text("edit ›").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).fill(AppColor.surface))
            .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).stroke(AppColor.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
