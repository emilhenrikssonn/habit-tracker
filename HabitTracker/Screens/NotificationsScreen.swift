import SwiftUI
import SwiftData

struct NotificationsScreen: View {
    @Query private var prefsList: [AppPrefs]
    @Environment(\.modelContext) private var ctx
    var onClose: () -> Void

    private var prefs: AppPrefs {
        if let p = prefsList.first { return p }
        let p = AppPrefs()
        ctx.insert(p)
        try? ctx.save()
        return p
    }

    var body: some View {
        ScreenScaffold {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        titleBlock
                        dailyBlock
                        rescueCard
                        previewCard
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, AppMetrics.hPadding)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: onClose) {
                Text("‹ back").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
            }.buttonStyle(.plain)
            Spacer()
            SectionLabel(text: "notifications")
        }
        .padding(.horizontal, AppMetrics.hPadding).padding(.top, 18).padding(.bottom, 20)
    }

    private var titleBlock: some View {
        Text("Notifications & streak rescue")
            .font(AppFont.serif(36)).foregroundStyle(AppColor.ink)
    }

    private var dailyBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "Daily").padding(.bottom, 8)
            HRule()
            DisclosureRow(
                title: "Morning plan",
                trailing: "\(prefs.morningPlanTime) · what's due today"
            )
            HRule()
            DisclosureRow(
                title: "Evening check-in",
                trailing: "\(prefs.eveningCheckinTime) · only if something is unlogged"
            )
            HRule()
            DisclosureRow(
                title: "Per-habit reminders",
                trailing: "\(prefs.perHabitReminderCount) on"
            )
            HRule()
        }
    }

    private var rescueCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Streak rescue")
            VStack(spacing: 0) {
                ToggleRow(
                    title: "Streak rescue",
                    subtitle: prefs.streakRescueEnabled
                        ? "Warns before a streak breaks."
                        : "Off · streaks break silently.",
                    isOn: Binding(
                        get: { prefs.streakRescueEnabled },
                        set: { prefs.streakRescueEnabled = $0; try? ctx.save() }
                    )
                )
                .padding(.horizontal, 16)
                HRule().padding(.leading, 16)
                DisclosureRow(
                    title: "Protect streaks over",
                    trailing: "\(prefs.streakRescueMinDays) days",
                    dimmed: !prefs.streakRescueEnabled
                )
                .padding(.horizontal, 16)
                HRule().padding(.leading, 16)
                DisclosureRow(
                    title: "Alert at",
                    trailing: prefs.streakRescueAlertTime,
                    dimmed: !prefs.streakRescueEnabled
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
            .background(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).fill(AppColor.surfaceAccent))
            .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).stroke(AppColor.borderAccent, lineWidth: 1))
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Preview · 20:30")
            VStack(alignment: .leading, spacing: 8) {
                Text("12 days of Exercise on the line")
                    .font(AppFont.serif(21)).foregroundStyle(AppColor.ink)
                Text("18 of 30 minutes logged. 12 left to keep the streak — or use a rest day.")
                    .font(AppFont.sans(13)).foregroundStyle(AppColor.accentSoft)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).fill(AppColor.surface))
            .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).stroke(AppColor.border, lineWidth: 1))
        }
    }
}
