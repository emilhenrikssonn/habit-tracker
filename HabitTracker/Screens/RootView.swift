import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var scenePhase
    @Query private var prefsList: [AppPrefs]
    private var store: Store { Store.shared }

    @State private var tab: RootTab = {
        if let tabArg = ProcessInfo.processInfo.environment["START_TAB"],
           let i = Int(tabArg), let t = RootTab(rawValue: i) {
            return t
        }
        return .today
    }()
    @State private var addHabitPresented: Bool = ProcessInfo.processInfo.environment["OPEN_ADD"] == "1"
    @State private var openHabit: Habit? = nil
    @State private var notificationsPresented: Bool = ProcessInfo.processInfo.environment["OPEN_NOTIFS"] == "1"

    var body: some View {
        Group {
            if let prefs = prefsList.first, !prefs.hasOnboarded {
                OnboardingScreen(prefs: prefs)
                    .transition(.opacity)
            } else {
                // Everything needs a subscription. Habits and logs stay on the device either way.
                switch store.access {
                case .unknown: ScreenScaffold { EmptyView() }
                case .notSubscribed: PaywallScreen().transition(.opacity)
                case .subscribed: main.transition(.opacity)
                }
            }
        }
        .task { await store.start() }
        .onChange(of: scenePhase) { _, phase in
            // Rebuild notifications from the latest logs whenever the app opens or leaves the screen.
            guard phase != .inactive else { return }
            Task {
                if phase == .active { await store.refreshAccess() }
                await NotificationScheduler.reschedule(in: ctx)
            }
        }
    }

    private var main: some View {
        ScreenScaffold {
            VStack(spacing: 0) {
                Group {
                    switch tab {
                    case .today:
                        TodayScreen(onOpenHabit: { openHabit = $0 }, onAdd: { addHabitPresented = true })
                    case .habits:
                        HabitsScreen(
                            onAdd: { addHabitPresented = true },
                            onOpenHabit: { openHabit = $0 }
                        )
                    case .stats:
                        StatisticsScreen()
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
        .sheet(isPresented: $notificationsPresented) {
            NotificationsScreen(onClose: { notificationsPresented = false })
        }
    }
}
