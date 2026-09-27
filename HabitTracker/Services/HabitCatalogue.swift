import Foundation

struct CatalogueEntry: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: HabitCategory
    let tracking: TrackingType
    let unit: String
    let goal: Double
    let type: HabitType

    var goalString: String {
        switch tracking {
        case .done: return "done"
        case .amount: return "amount · \(Int(goal)) \(unit)/day"
        case .time: return "time · \(Int(goal)) \(unit)/day"
        }
    }

    var summary: String {
        "\(category.display) · \(goalString)"
    }
}

enum HabitCatalogue {
    static let entries: [CatalogueEntry] = [
        .init(name: "Drink water", category: .health, tracking: .amount, unit: "glasses", goal: 8, type: .build),
        .init(name: "Sleep by 23:00", category: .health, tracking: .done, unit: "", goal: 1, type: .build),
        .init(name: "Take vitamins", category: .health, tracking: .done, unit: "", goal: 1, type: .build),
        .init(name: "Exercise", category: .movement, tracking: .time, unit: "min", goal: 30, type: .build),
        .init(name: "Walk 8 000 steps", category: .movement, tracking: .amount, unit: "steps", goal: 8000, type: .build),
        .init(name: "Stretch", category: .movement, tracking: .time, unit: "min", goal: 10, type: .build),
        .init(name: "Meditate", category: .mind, tracking: .time, unit: "min", goal: 10, type: .build),
        .init(name: "Read", category: .mind, tracking: .amount, unit: "pages", goal: 20, type: .build),
        .init(name: "Journal", category: .mind, tracking: .done, unit: "", goal: 1, type: .build),
        .init(name: "No screens after 22", category: .quit, tracking: .done, unit: "", goal: 1, type: .quit),
        .init(name: "No sugar", category: .quit, tracking: .done, unit: "", goal: 1, type: .quit),
        .init(name: "Less social media", category: .quit, tracking: .time, unit: "min max", goal: 30, type: .quit)
    ]
}
