import SwiftUI
import SwiftData

private enum StatsRange: String, CaseIterable, Identifiable {
    case d7 = "7 d", d30 = "30 d", d90 = "90 d", year = "Year", custom = "Custom"
    var id: String { rawValue }
}

struct StatisticsScreen: View {
    @Query(sort: [SortDescriptor(\Habit.sortIndex)]) private var habits: [Habit]
    @State private var range: StatsRange = .d30

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBlock
            rangeTabs
            dateLine
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    completionBlock
                    weekdayBlock
                    perHabitBlock
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, AppMetrics.hPadding)
            }
        }
    }

    private var titleBlock: some View {
        Text("Statistics")
            .font(AppFont.serif(40)).foregroundStyle(AppColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppMetrics.hPadding)
            .padding(.top, 20).padding(.bottom, 16)
    }

    private var rangeTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StatsRange.allCases) { r in
                    CategoryChip(title: r.rawValue, isActive: range == r) { range = r }
                }
            }
            .padding(.horizontal, AppMetrics.hPadding)
        }
        .padding(.bottom, 8)
    }

    private var dateLine: some View {
        HStack {
            Text(rangeDates).font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
            Spacer()
            Text(range == .custom ? "edit dates ›" : "pick dates ›")
                .font(AppFont.mono(11)).foregroundStyle(AppColor.accent)
        }
        .padding(.horizontal, AppMetrics.hPadding)
        .padding(.bottom, 18)
    }

    private var rangeDates: String {
        switch range {
        case .d7: return "20 Sep – 26 Sep"
        case .d30: return "28 Aug – 26 Sep"
        case .d90: return "29 Jun – 26 Sep"
        case .year: return "27 Sep 2024 – 26 Sep 2025"
        case .custom: return "10 Aug – 26 Sep"
        }
    }

    private var completionBlock: some View {
        let (rate, kept, total, perfect, streak) = rangeStats
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(rate)%")
                    .font(AppFont.mono(46))
                    .foregroundStyle(AppColor.accent)
                Text("completion rate")
                    .font(AppFont.mono(11))
                    .foregroundStyle(AppColor.inkMute)
            }
            HStack(spacing: 10) {
                statCard("KEPT", "\(kept)/\(total)")
                statCard("STREAK", "\(streak) d")
                statCard("PERFECT", "\(perfect)")
            }
        }
    }

    private func statCard(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFont.mono(10, weight: .medium))
                .tracking(10 * 0.16)
                .foregroundStyle(AppColor.inkMute)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(AppFont.mono(20))
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).fill(AppColor.surface))
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).stroke(AppColor.border, lineWidth: 1))
    }

    private var rangeStats: (rate: Int, kept: Int, total: Int, perfect: Int, streak: Int) {
        switch range {
        case .d7: return (86, 6, 7, 4, 6)
        case .d30: return (74, 22, 30, 11, 6)
        case .d90: return (68, 61, 90, 29, 8)
        case .year: return (71, 259, 365, 103, 11)
        case .custom: return (79, 38, 48, 17, 6)
        }
    }

    private var weekdayBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "By weekday")
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(0..<7, id: \.self) { i in
                    weekdayBar(day: dayNames[i], value: weekdayValues[i])
                }
            }
            Text("Fridays are your best day — kept **93 %**. Wednesdays lag at **48 %**.")
                .font(AppFont.sans(13))
                .foregroundStyle(AppColor.inkMute)
        }
    }

    private let dayNames = ["Mo","Tu","We","Th","Fr","Sa","Su"]
    private var weekdayValues: [Int] { [72, 61, 48, 78, 93, 84, 66] }

    private func weekdayBar(day: String, value: Int) -> some View {
        VStack(spacing: 6) {
            Text("\(value)%")
                .font(AppFont.mono(10))
                .foregroundStyle(AppColor.inkMute)
            let color: Color = value >= 80 ? AppColor.accent : (value >= 60 ? AppColor.accentMid : AppColor.borderStrong)
            RoundedRectangle(cornerRadius: 3).fill(color)
                .frame(width: 22, height: CGFloat(value) * 0.9)
            Text(day)
                .font(AppFont.mono(10))
                .foregroundStyle(AppColor.inkMute)
        }
        .frame(maxWidth: .infinity)
    }

    private var perHabitBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Per habit")
            ForEach(habits.filter { !$0.archived }, id: \.id) { h in
                perHabitRow(h)
            }
        }
    }

    private func perHabitRow(_ habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(habit.name)
                    .font(AppFont.serif(21))
                    .foregroundStyle(AppColor.ink)
                Spacer()
                Text("\(habitRate(habit))% · up 8")
                    .font(AppFont.mono(11))
                    .foregroundStyle(AppColor.inkMute)
                    .lineLimit(1)
            }
            heatmap(habit: habit)
        }
        .padding(.vertical, 10)
    }

    private func heatmap(habit: Habit) -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var cells: [Color] = []
        for offset in stride(from: 27, through: 0, by: -1) {
            let d = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            let log = habit.logs.first { cal.isDate($0.date, inSameDayAs: d) }
            if let log {
                if log.completed { cells.append(AppColor.accent) }
                else if log.value > 0 { cells.append(AppColor.accentMid) }
                else { cells.append(AppColor.border) }
            } else {
                cells.append(AppColor.border)
            }
        }
        return HStack(spacing: 4) {
            ForEach(cells.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2).fill(cells[i]).frame(height: 14)
            }
        }
    }

    private func habitRate(_ habit: Habit) -> Int {
        let logs = habit.logs
        guard !logs.isEmpty else { return 0 }
        let done = logs.filter { $0.completed }.count
        return Int(Double(done) / Double(logs.count) * 100)
    }
}
