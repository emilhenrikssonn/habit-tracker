import SwiftUI

enum RootTab: Int, CaseIterable, Identifiable {
    case today, habits, stats, friends, settings
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .today: return "TODAY"
        case .habits: return "HABITS"
        case .stats: return "STATS"
        case .friends: return "FRIENDS"
        case .settings: return "SET"
        }
    }
    var shortLabel: String {
        switch self {
        case .today: return "TOD"
        case .habits: return "HAB"
        case .stats: return "STA"
        case .friends: return "FRI"
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
                tabItem(.friends)
                tabItem(.settings)
            }
            .padding(.horizontal, AppMetrics.hPadding)
            .padding(.top, 14)
            .padding(.bottom, 26)
        }
        .background(AppColor.bg)
    }

    @ViewBuilder
    private func tabItem(_ tab: RootTab) -> some View {
        Button {
            selection = tab
        } label: {
            Text(tab.label)
                .font(AppFont.mono(10, weight: .medium))
                .tracking(10 * 0.16)
                .foregroundStyle(selection == tab ? AppColor.ink : AppColor.inkDim)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
        }
        .buttonStyle(.plain)
    }

    private var fab: some View {
        Button(action: onPlus) {
            ZStack {
                Circle().fill(AppColor.accent).frame(width: 38, height: 38)
                Text("+")
                    .font(AppFont.serif(24))
                    .foregroundStyle(AppColor.inkOnAccent)
                    .offset(y: -1)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
