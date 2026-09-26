import Foundation
import SwiftUI

enum HabitCategory: String, Codable, CaseIterable, Identifiable {
    case health, movement, mind, quit
    var id: String { rawValue }
    var display: String {
        switch self {
        case .health: return "Health"
        case .movement: return "Movement"
        case .mind: return "Mind"
        case .quit: return "Quit"
        }
    }
}

enum HabitType: String, Codable {
    case build, quit
    var display: String { self == .build ? "Build" : "Quit" }
}

enum TrackingType: String, Codable, CaseIterable, Identifiable {
    case done, count, amount, time
    var id: String { rawValue }
    var display: String {
        switch self {
        case .done: return "Done"
        case .count: return "Count"
        case .amount: return "Amount"
        case .time: return "Time"
        }
    }
    var caption: String {
        switch self {
        case .done: return "yes / no"
        case .count: return "glasses, sets"
        case .amount: return "km, pages, ml"
        case .time: return "minutes, timer"
        }
    }
    var hint: String {
        switch self {
        case .done: return "One tap on Today marks the day complete."
        case .count: return "Tap to add one at a time — reaching the goal completes the day."
        case .amount: return "Log a measured amount; partial days still show progress."
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
