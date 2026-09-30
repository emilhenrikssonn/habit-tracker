import Foundation
import SwiftData

enum HomeViewStyle: String, Codable, CaseIterable {
    case list, grid
}

@Model
final class AppPrefs {
    var id: UUID = UUID()
    var hasOnboarded: Bool = false
    var displayName: String = "You"
    var defaultViewRaw: String = HomeViewStyle.list.rawValue
    var customCategories: [String] = []

    // Notifications. Times are "HH:mm"; weekdays are Monday=1…Sunday=7.
    var habitRemindersEnabled: Bool = true
    var morningPlanEnabled: Bool = false
    var morningPlanTime: String = "07:30"
    var eveningCheckinEnabled: Bool = true
    var eveningCheckinTime: String = "21:00"
    var streakRescueEnabled: Bool = true
    var streakRescueMinDays: Int = 7
    var streakRescueAlertTime: String = "20:30"
    var weeklyReportEnabled: Bool = false
    var weeklyReportWeekday: Int = 7

    init() {}

    var defaultView: HomeViewStyle {
        get { HomeViewStyle(rawValue: defaultViewRaw) ?? .list }
        set { defaultViewRaw = newValue.rawValue }
    }

    /// How many kinds of notification are switched on.
    var enabledNotificationCount: Int {
        [habitRemindersEnabled, morningPlanEnabled, eveningCheckinEnabled, streakRescueEnabled, weeklyReportEnabled]
            .filter { $0 }.count
    }

    func disableAllNotifications() {
        habitRemindersEnabled = false
        morningPlanEnabled = false
        eveningCheckinEnabled = false
        streakRescueEnabled = false
        weeklyReportEnabled = false
    }
}
