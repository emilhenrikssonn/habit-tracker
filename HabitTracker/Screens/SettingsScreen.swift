import StoreKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications

struct SettingsScreen: View {
    @Query private var prefsList: [AppPrefs]
    @Query(filter: #Predicate<HabitLog> { $0.completed }) private var keptLogs: [HabitLog]
    @Query private var habits: [Habit]
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    var onOpenNotifications: () -> Void

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var editingName = false
    @State private var nameDraft = ""
    @State private var exportFile: ExportFile? = nil
    @State private var managingSubscription = false
    @State private var showingGuide = false
    @State private var choosingBackup = false
    /// A backup read from Files, waiting for the person to confirm it may replace what's here.
    @State private var pendingRestore: BackupFile? = nil
    @State private var notice: Notice? = nil

    private struct Notice: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
    @AppStorage("weekStart") private var weekStart = 1
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .dark

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
                    DisclosureRow(title: "Theme", trailing: theme.display,
                                  subtitle: "Dark or light", showChevron: false) {
                        theme = theme == .dark ? .light : .dark
                    }
                    HRule()
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
                    DisclosureRow(title: "Time-of-day stats", trailing: prefs.timeStatsEnabled ? "On" : "Off",
                                  subtitle: prefs.timeStatsEnabled ? "I tick habits off as I do them" : "I log everything at once",
                                  showChevron: false) {
                        prefs.timeStatsEnabled.toggle()
                        try? ctx.save()
                    }
                    HRule()
                    Text("Tap a setting above to switch it. Turn time-of-day stats off if you log all your habits at once, for example in the evening, so stats don't show when you usually do them.")
                        .font(AppFont.mono(10)).foregroundStyle(AppColor.inkMute)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)

                    SectionLabel(text: "Your data").padding(.top, 24)
                    HRule().padding(.top, 8)
                    DisclosureRow(title: "Back up data", trailing: "file",
                                  subtitle: "Everything, to move to a new phone") {
                        exportFile = Backup.file(in: ctx).map(ExportFile.init)
                        if exportFile == nil { notice = Notice(title: "Couldn't make a backup", message: "Please try again.") }
                    }
                    HRule()
                    DisclosureRow(title: "Restore from backup",
                                  subtitle: "Replaces what's on this phone") {
                        choosingBackup = true
                    }
                    HRule()
                    DisclosureRow(title: "Export as spreadsheet", trailing: "CSV",
                                  subtitle: "Every habit and log, for Numbers or Excel") {
                        exportFile = DataExport.csvFile(in: ctx).map(ExportFile.init)
                    }
                    HRule()
                    Text("Your data stays on this iPhone. Save a backup to Files or iCloud Drive, then restore it on your new phone.")
                        .font(AppFont.mono(10)).foregroundStyle(AppColor.inkMute)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)

                    SectionLabel(text: "About").padding(.top, 24)
                    HRule().padding(.top, 8)
                    DisclosureRow(title: "How Habits works",
                                  subtitle: "A guide to every feature") {
                        showingGuide = true
                    }
                    HRule()
                    DisclosureRow(title: "Subscription", trailing: "active",
                                  subtitle: "Change plan or cancel") {
                        managingSubscription = true
                    }
                    HRule()
                    DisclosureRow(title: "Terms of use") {
                        openURL(PaywallScreen.termsURL)
                    }
                    HRule()
                    DisclosureRow(title: "Privacy policy",
                                  subtitle: "Everything stays on this iPhone") {
                        openURL(URL(string: "https://emilhenrikssonn.github.io/habit-tracker/privacy-policy.html")!)
                    }
                    HRule()

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, AppMetrics.hPadding)
            }
        }
        .task { notificationStatus = await NotificationScheduler.status() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { notificationStatus = await NotificationScheduler.status() } }
        }
        .manageSubscriptionsSheet(isPresented: $managingSubscription)
        .sheet(item: $exportFile) { file in
            ShareSheet(items: [file.url])
        }
        .fullScreenCover(isPresented: $showingGuide) {
            GuideScreen(onClose: { showingGuide = false })
        }
        .fileImporter(isPresented: $choosingBackup, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                do {
                    pendingRestore = try Backup.read(from: url)
                } catch {
                    notice = Notice(title: "Couldn't open backup", message: error.localizedDescription)
                }
            case .failure(let error):
                notice = Notice(title: "Couldn't open backup", message: error.localizedDescription)
            }
        }
        .confirmationDialog("Restore this backup?",
                            isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
                            titleVisibility: .visible, presenting: pendingRestore) { backup in
            Button("Replace and restore", role: .destructive) { restore(backup) }
            Button("Cancel", role: .cancel) {}
        } message: { backup in
            Text(restoreSummary(backup))
        }
        .alert(item: $notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
        }
        .alert("Your name", isPresented: $editingName) {
            TextField("Name", text: $nameDraft)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = nameDraft.cleanedInput(maxLength: TextLimit.displayName)
                prefs.displayName = trimmed.isEmpty ? "You" : trimmed
                try? ctx.save()
            }
        }
    }

    private func restoreSummary(_ backup: BackupFile) -> String {
        let date = backup.exportedAt.formatted(date: .abbreviated, time: .shortened)
        let logged = backup.habits.reduce(0) { $0 + $1.logs.count }
        let incoming = "The backup from \(date) has \(Self.count(backup.habits.count, "habit")) and \(Self.count(logged, "logged day"))."
        guard !habits.isEmpty else { return incoming }
        return incoming + " It replaces the \(Self.count(habits.count, "habit")) on this phone and all their history. This can't be undone."
    }

    private func restore(_ backup: BackupFile) {
        pendingRestore = nil
        do {
            try Backup.restore(backup, into: ctx)
            notice = Notice(title: "Backup restored",
                            message: "\(Self.count(backup.habits.count, "habit")) and their history are on this phone now.")
            let ctx = ctx
            Task {
                if let prefs = try? ctx.fetch(FetchDescriptor<AppPrefs>()).first, prefs.enabledNotificationCount > 0 {
                    await NotificationScheduler.requestPermission()
                }
                await NotificationScheduler.reschedule(in: ctx)
            }
        } catch {
            notice = Notice(title: "Couldn't restore", message: "Nothing was changed. \(error.localizedDescription)")
        }
    }

    private static func count(_ n: Int, _ noun: String) -> String {
        n == 1 ? "1 \(noun)" : "\(n) \(noun)s"
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
