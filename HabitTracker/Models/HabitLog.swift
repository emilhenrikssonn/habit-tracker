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
    /// When the day was ticked off or its goal reached. Nil for logs from before this was recorded.
    var completedAt: Date? = nil

    var habit: Habit?

    init(date: Date = Date(), value: Double = 0, completed: Bool = false, skipped: Bool = false, note: String = "") {
        self.date = Calendar.current.startOfDay(for: date)
        self.value = value
        self.completed = completed
        self.skipped = skipped
        self.note = note
        if completed { completedAt = Date() }
    }

    /// Sets `completed`, stamping the time it became kept and clearing it when undone.
    func setCompleted(_ kept: Bool, at time: Date = Date()) {
        if kept && !completed { completedAt = time }
        if !kept { completedAt = nil }
        completed = kept
    }
}
