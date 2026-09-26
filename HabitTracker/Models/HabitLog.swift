import Foundation
import SwiftData

@Model
final class HabitLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var value: Double = 0
    var completed: Bool = false
    var skipped: Bool = false
    var note: String = ""

    var habit: Habit?

    init(date: Date = Date(), value: Double = 0, completed: Bool = false, skipped: Bool = false, note: String = "") {
        self.date = Calendar.current.startOfDay(for: date)
        self.value = value
        self.completed = completed
        self.skipped = skipped
        self.note = note
    }
}
