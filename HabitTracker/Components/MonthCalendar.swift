import SwiftUI

struct CalendarDayStyle {
    var fill: Color = AppColor.surface
    var text: Color = AppColor.ink
    var stroke: Color? = nil
}

/// A month grid with previous/next buttons. Each day's look comes from `dayStyle`;
/// days are tappable when `onTap` is set.
struct MonthCalendar: View {
    /// Any date in the month being shown.
    @Binding var month: Date
    var dayStyle: (Date) -> CalendarDayStyle
    var onTap: ((Date) -> Void)? = nil

    @AppStorage("weekStart") private var weekStart = 1

    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                navButton("‹", months: -1)
                Spacer()
                Text(firstOfMonth.formatted(.dateTime.month(.wide).year()))
                    .font(AppFont.serif(22))
                    .foregroundStyle(AppColor.ink)
                Spacer()
                navButton("›", months: 1)
            }
            HStack(spacing: 6) {
                ForEach(Habit.orderedWeekdays, id: \.self) { day in
                    Text(Habit.dayLetter(day))
                        .font(AppFont.mono(10, weight: .medium))
                        .foregroundStyle(AppColor.inkMute)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(0..<cells.count, id: \.self) { i in
                    if let date = cells[i] {
                        cell(date)
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
        }
    }

    private var firstOfMonth: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: month))!
    }

    private var cells: [Date?] {
        let first = firstOfMonth
        let weekday = ClockTime.weekday(of: first)
        let leading = weekStart == 7 ? weekday % 7 : weekday - 1
        let days = cal.range(of: .day, in: .month, for: first)!.count
        return Array(repeating: nil, count: leading)
            + (0..<days).map { cal.date(byAdding: .day, value: $0, to: first) }
    }

    private func navButton(_ label: String, months: Int) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                month = cal.date(byAdding: .month, value: months, to: firstOfMonth)!
            }
        } label: {
            Text(label)
                .font(AppFont.mono(16))
                .foregroundStyle(AppColor.accent)
                .frame(width: 36, height: 36)
                .background(Circle().stroke(AppColor.accentMid, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func cell(_ date: Date) -> some View {
        let style = dayStyle(date)
        let label = Text("\(cal.component(.day, from: date))")
            .font(AppFont.mono(12))
            .foregroundStyle(style.text)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(RoundedRectangle(cornerRadius: 8).fill(style.fill))
            .overlay {
                if let stroke = style.stroke {
                    RoundedRectangle(cornerRadius: 8).stroke(stroke, lineWidth: 1)
                }
            }
        if let onTap {
            Button { onTap(date) } label: { label.contentShape(Rectangle()) }
                .buttonStyle(.plain)
        } else {
            label
        }
    }
}

/// Sheet chrome around a calendar: title, a line of context, Done and an optional Clear.
struct CalendarSheet<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var onDone: () -> Void
    var onClear: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScreenScaffold {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(AppFont.serif(30)).foregroundStyle(AppColor.ink)
                    Spacer()
                    if let onClear {
                        Button(action: onClear) {
                            Text("Clear").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 14)
                    }
                    Button(action: onDone) {
                        Text("Done").font(AppFont.mono(12)).foregroundStyle(AppColor.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 22)
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.sans(14)).foregroundStyle(AppColor.inkDim)
                        .padding(.top, 6)
                }
                content().padding(.top, 20)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppMetrics.hPadding)
        }
        .presentationDetents([.height(520)])
    }
}
