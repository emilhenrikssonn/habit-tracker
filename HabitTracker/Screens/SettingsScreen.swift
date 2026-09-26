import SwiftUI
import SwiftData

struct SettingsScreen: View {
    @Query private var prefsList: [AppPrefs]
    @Environment(\.modelContext) private var ctx
    var onOpenNotifications: () -> Void

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
                    DisclosureRow(title: "Notifications", trailing: "3 active",
                                  trailingColor: AppColor.accent) {
                        onOpenNotifications()
                    }
                    HRule()
                    DisclosureRow(title: "Evening summary", trailing: prefs.eveningSummaryTime)
                    HRule()
                    DisclosureRow(title: "Weekly report", trailing: prefs.weeklyReportDay)
                    HRule()

                    SectionLabel(text: "Streaks").padding(.top, 24)
                    HRule().padding(.top, 8)
                    ToggleRow(
                        title: "Streak rescue",
                        subtitle: prefs.streakRescueEnabled
                            ? "Warns at \(prefs.streakRescueAlertTime) · streaks over \(prefs.streakRescueMinDays) days"
                            : "Off · streaks break silently",
                        isOn: Binding(
                            get: { prefs.streakRescueEnabled },
                            set: { prefs.streakRescueEnabled = $0; try? ctx.save() }
                        )
                    )
                    HRule()
                    DisclosureRow(
                        title: "Rescue rules",
                        trailing: "\(prefs.streakRescueMinDays)+ days, \(prefs.streakRescueAlertTime)",
                        dimmed: !prefs.streakRescueEnabled
                    )
                    HRule()
                    DisclosureRow(title: "Rest days", trailing: "\(prefs.restDaysPerMonth) / month")
                    HRule()

                    SectionLabel(text: "App").padding(.top, 24)
                    HRule().padding(.top, 8)
                    DisclosureRow(title: "Default view", trailing: prefs.defaultView == .list ? "List" : "Grid")
                    HRule()
                    DisclosureRow(title: "Week starts", trailing: prefs.weekStart == 1 ? "Monday" : "Sunday")
                    HRule()
                    DisclosureRow(title: "Export & backup", trailing: "CSV")
                    HRule()

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, AppMetrics.hPadding)
            }
        }
    }

    private var titleBlock: some View {
        Text("Settings")
            .font(AppFont.serif(40)).foregroundStyle(AppColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppMetrics.hPadding)
            .padding(.top, 20).padding(.bottom, 12)
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(AppColor.accentMid).frame(width: 46, height: 46)
                Text(String(prefs.displayName.prefix(1)))
                    .font(AppFont.serif(22))
                    .foregroundStyle(AppColor.accentSoftLight)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(prefs.displayName).font(AppFont.serif(22)).foregroundStyle(AppColor.ink)
                Text("Synced · \(prefs.tracked) days tracked")
                    .font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
            }
            Spacer()
            Text("›").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).fill(AppColor.surface))
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).stroke(AppColor.border, lineWidth: 1))
    }
}
