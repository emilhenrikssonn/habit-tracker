import Foundation
import SwiftData
import SwiftUI
import UIKit

/// Writes every habit and log to a CSV file for the share sheet. The file stays on the device
/// until the person chooses where to send it.
enum DataExport {
    static func csvFile(in ctx: ModelContext) -> URL? {
        let habits = (try? ctx.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortIndex)]))) ?? []
        let dayFmt = Date.ISO8601FormatStyle().year().month().day()
        var lines = ["habit,category,status,date,value,unit,goal,completed,note"]
        for habit in habits {
            let status = habit.archived ? "archived" : "active"
            for log in habit.logs.sorted(by: { $0.date < $1.date }) {
                lines.append([
                    habit.name, habit.categoryName, status, log.date.formatted(dayFmt),
                    habit.format(log.value), habit.unitLabel, habit.format(habit.dailyGoal),
                    log.completed ? "yes" : "no", log.note
                ].map(escape).joined(separator: ","))
            }
        }
        let name = "habits-\(Date().formatted(dayFmt)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(where: { ",\"\n".contains($0) }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

struct ExportFile: Identifiable {
    let url: URL
    var id: URL { url }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
