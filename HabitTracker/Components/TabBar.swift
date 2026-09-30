import SwiftUI

enum RootTab: Int, CaseIterable, Identifiable {
    case today, habits, stats, settings
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .today: return "TODAY"
        case .habits: return "HABITS"
        case .stats: return "STATS"
        case .settings: return "SET"
        }
    }
    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .habits: return "list.bullet"
        case .stats: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
    var shortLabel: String {
        switch self {
        case .today: return "TOD"
        case .habits: return "HAB"
        case .stats: return "STA"
        case .settings: return "SET"
        }
    }
}

struct AppTabBar: View {
    @Binding var selection: RootTab
    var onPlus: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HRule()
            HStack(alignment: .center, spacing: 0) {
                tabItem(.today)
                tabItem(.habits)
                fab
                tabItem(.stats)
                tabItem(.settings)
            }
            .padding(.horizontal, AppMetrics.hPadding)
            .padding(.top, 10)
            .padding(.bottom, 22)
        }
        .background(AppColor.bg)
    }

    @ViewBuilder
    private func tabItem(_ tab: RootTab) -> some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15, weight: selection == tab ? .semibold : .regular))
                    .frame(height: 18)
                Text(tab.label)
                    .font(AppFont.mono(10, weight: .medium))
                    .tracking(10 * 0.16)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
            }
            .foregroundStyle(selection == tab ? AppColor.ink : AppColor.inkDim)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var fab: some View {
        Button(action: onPlus) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColor.inkOnAccent)
                .frame(width: 42, height: 42)
                .background(Circle().fill(AppColor.accent))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
