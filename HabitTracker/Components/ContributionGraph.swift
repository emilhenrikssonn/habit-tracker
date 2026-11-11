import SwiftUI

/// A year at a glance: one column per week, one row per weekday, this week on the right.
/// `share` gives the part kept on a day, 0…1, or nil when nothing was due.
struct ContributionGraph: View {
    var weeks: Int = 53
    var share: (Date) -> Double?

    @AppStorage("weekStart") private var weekStart = 1

    private let cal = Calendar.current
    private let cell: CGFloat = 12
    private let gap: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 6) {
                weekdayLabels
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: gap) {
                        ForEach(columns, id: \.self) { column($0) }
                    }
                }
                .defaultScrollAnchor(.trailing)
            }
            legend
        }
        .id(weekStart)
    }

    /// First day of each week shown, oldest first.
    private var columns: [Date] {
        let last = Habit.startOfWeek(containing: Date())
        return (0..<weeks).reversed().map { cal.date(byAdding: .day, value: -7 * $0, to: last)! }
    }

    private var weekdayLabels: some View {
        VStack(alignment: .leading, spacing: gap) {
            Color.clear.frame(height: 14)
            ForEach(Array(Habit.orderedWeekdays.enumerated()), id: \.offset) { i, day in
                Text(i % 2 == 1 ? String(Habit.dayShort(day).prefix(1)) : "")
                    .font(AppFont.mono(9)).foregroundStyle(AppColor.inkMute)
                    .frame(width: 10, height: cell)
            }
        }
    }

    private func column(_ weekStart: Date) -> some View {
        let days = (0..<7).map { cal.date(byAdding: .day, value: $0, to: weekStart)! }
        let firstOfMonth = days.first { cal.component(.day, from: $0) == 1 }
        return VStack(spacing: gap) {
            Text(firstOfMonth?.formatted(.dateTime.month(.abbreviated)) ?? "")
                .font(AppFont.mono(9)).foregroundStyle(AppColor.inkMute)
                .fixedSize()
                .frame(width: cell, height: 14, alignment: .leading)
            ForEach(days, id: \.self) { day in
                RoundedRectangle(cornerRadius: 2.5).fill(color(day)).frame(width: cell, height: cell)
            }
        }
    }

    private func color(_ day: Date) -> Color {
        if day > cal.startOfDay(for: Date()) { return .clear }
        guard let s = share(day) else { return AppColor.border.opacity(0.35) }
        return Self.shade(s)
    }

    static func shade(_ share: Double) -> Color {
        switch share {
        case 1...: return AppColor.accent
        case 0.5...: return AppColor.accentMid
        case 0.01...: return AppColor.accentMid.opacity(0.5)
        default: return AppColor.borderStrong
        }
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text("not due").font(AppFont.mono(10)).foregroundStyle(AppColor.inkMute)
            RoundedRectangle(cornerRadius: 2.5).fill(AppColor.border.opacity(0.35)).frame(width: 10, height: 10)
            Spacer()
            Text("missed").font(AppFont.mono(10)).foregroundStyle(AppColor.inkMute)
            ForEach([0, 0.3, 0.6, 1], id: \.self) { s in
                RoundedRectangle(cornerRadius: 2.5).fill(Self.shade(s)).frame(width: 10, height: 10)
            }
            Text("kept").font(AppFont.mono(10)).foregroundStyle(AppColor.inkMute)
        }
    }
}
