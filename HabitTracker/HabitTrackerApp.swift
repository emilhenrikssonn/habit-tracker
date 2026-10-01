import SwiftUI
import SwiftData

@main
struct HabitTrackerApp: App {
    let container: ModelContainer
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .dark

    init() {
        let schema = Schema([Habit.self, HabitLog.self, AppPrefs.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        container = (try? ModelContainer(for: schema, configurations: [config]))
            ?? {
                let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try! ModelContainer(for: schema, configurations: [fallback])
            }()
        SeedData.installIfNeeded(container: container)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .preferredColorScheme(theme.colorScheme)
                .tint(AppColor.accent)
        }
    }
}
