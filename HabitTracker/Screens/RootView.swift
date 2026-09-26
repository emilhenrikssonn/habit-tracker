import SwiftUI
import SwiftData

struct RootView: View {
    @State private var tab: RootTab = {
        if let tabArg = ProcessInfo.processInfo.environment["START_TAB"],
           let i = Int(tabArg), let t = RootTab(rawValue: i) {
            return t
        }
        return .today
    }()
    @State private var addHabitPresented: Bool = ProcessInfo.processInfo.environment["OPEN_ADD"] == "1"
    @State private var openHabit: Habit? = nil
    @State private var openShareFor: Habit? = nil
    @State private var notificationsPresented: Bool = ProcessInfo.processInfo.environment["OPEN_NOTIFS"] == "1"

    var body: some View {
        ScreenScaffold {
            VStack(spacing: 0) {
                Group {
                    switch tab {
                    case .today:
                        TodayScreen(onOpenHabit: { openHabit = $0 })
                    case .habits:
                        HabitsScreen(
                            onAdd: { addHabitPresented = true },
                            onOpenHabit: { openHabit = $0 }
                        )
                    case .stats:
                        StatisticsScreen()
                    case .friends:
                        FriendsScreen(onShare: { openShareFor = $0 })
                    case .settings:
                        SettingsScreen(onOpenNotifications: { notificationsPresented = true })
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                AppTabBar(selection: $tab, onPlus: { addHabitPresented = true })
            }
        }
        .sheet(isPresented: $addHabitPresented) {
            AddHabitScreen(onClose: { addHabitPresented = false })
        }
        .sheet(item: $openHabit) { habit in
            HabitDetailScreen(habit: habit, onClose: { openHabit = nil })
        }
        .sheet(item: $openShareFor) { habit in
            ShareHabitScreen(habit: habit, onClose: { openShareFor = nil })
        }
        .sheet(isPresented: $notificationsPresented) {
            NotificationsScreen(onClose: { notificationsPresented = false })
        }
    }
}
