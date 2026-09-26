import Foundation
import SwiftData

enum HomeViewStyle: String, Codable, CaseIterable {
    case list, grid
}

@Model
final class AppPrefs {
    var id: UUID = UUID()
    var defaultViewRaw: String = HomeViewStyle.list.rawValue
    var weekStart: Int = 1 // Monday
    var streakRescueEnabled: Bool = true
    var streakRescueMinDays: Int = 7
    var streakRescueAlertTime: String = "20:30"
    var restDaysPerMonth: Int = 2
    var eveningSummaryTime: String = "21:00"
    var weeklyReportDay: String = "Sunday"
    var morningPlanTime: String = "07:30"
    var eveningCheckinTime: String = "21:00"
    var perHabitReminderCount: Int = 3
    var displayName: String = "You"
    var tracked: Int = 128

    init() {}

    var defaultView: HomeViewStyle {
        get { HomeViewStyle(rawValue: defaultViewRaw) ?? .list }
        set { defaultViewRaw = newValue.rawValue }
    }
}
