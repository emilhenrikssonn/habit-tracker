import Foundation
import SwiftUI

enum HabitCategory: String, Codable, CaseIterable, Identifiable {
    case health, movement, mind, focus, quit
    var id: String { rawValue }
    var display: String {
        switch self {
        case .health: return "Health"
        case .movement: return "Movement"
        case .mind: return "Mind"
        case .focus: return "Focus"
        case .quit: return "Quit"
        }
    }
}

enum HabitType: String, Codable {
    case build, quit
    var display: String { self == .build ? "Build" : "Quit" }
}

enum TrackingType: String, Codable, CaseIterable, Identifiable {
    // "count" was merged into amount; Habit.tracking reads old "count" habits as .amount.
    case done, amount, time
    var id: String { rawValue }
    var display: String {
        switch self {
        case .done: return "Done"
        case .amount: return "Amount"
        case .time: return "Time"
        }
    }
    var caption: String {
        switch self {
        case .done: return "yes / no"
        case .amount: return "pages, glasses, km"
        case .time: return "minutes, timer"
        }
    }
    var hint: String {
        switch self {
        case .done: return "One tap on Today marks the day complete."
        case .amount: return "Tap +1 or log more at once — reaching the goal completes the day."
        case .time: return "Log minutes by hand or run a timer inside the habit."
        }
    }
}

enum RepeatMode: String, Codable, CaseIterable, Identifiable {
    case daily, days, weekly, dates
    var id: String { rawValue }
    var display: String {
        switch self {
        case .daily: return "Daily"
        case .days: return "Days"
        case .weekly: return "× / week"
        case .dates: return "Dates"
        }
    }
}
