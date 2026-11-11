import SwiftUI
import SwiftData

/// Asks for today's total of an amount or time habit and saves it in place of what was logged.
struct AmountEntryAlert: ViewModifier {
    @Binding var habit: Habit?
    @Environment(\.modelContext) private var ctx
    @State private var text = ""

    func body(content: Content) -> some View {
        content.alert(title, isPresented: Binding(get: { habit != nil }, set: { if !$0 { habit = nil } })) {
            TextField(habit.map { $0.unitLabel.isEmpty ? "Amount" : $0.unitLabel } ?? "", text: $text)
                .keyboardType(.decimalPad)
            Button("Save") {
                if let habit, let value = Self.parse(text) { habit.setValue(value, in: ctx) }
                habit = nil
            }
            Button("Cancel", role: .cancel) { habit = nil }
        } message: {
            Text("Goal \(habit.map { $0.formatWithUnit($0.dailyGoal) } ?? ""). This replaces what's logged today.")
        }
        .onChange(of: habit?.persistentModelID) { _, _ in
            text = habit.map { $0.format($0.todayLog()?.value ?? 0) } ?? ""
            if text == "0" { text = "" }
        }
    }

    private var title: String { "Today's \(habit?.name ?? "amount")" }

    /// Accepts "8000", "8 000", "2,5" and "2.5".
    static func parse(_ text: String) -> Double? {
        let cleaned = text.filter { !$0.isWhitespace }.replacingOccurrences(of: ",", with: ".")
        return Double(cleaned).flatMap { $0 >= 0 ? $0 : nil }
    }
}

extension View {
    func amountEntry(for habit: Binding<Habit?>) -> some View {
        modifier(AmountEntryAlert(habit: habit))
    }
}
