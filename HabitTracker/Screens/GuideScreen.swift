import SwiftUI

/// "How Habits works": one feature per page, from adding a habit to backing up. Next moves on,
/// Back goes one page back, and Close leaves from any page. Opened from Settings.
struct GuideScreen: View {
    var onClose: () -> Void
    @State private var index = 0

    private let pages = GuidePage.all

    var body: some View {
        ScreenScaffold {
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    pageView(pages[index])
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppMetrics.hPadding)
                        .padding(.bottom, 24)
                }
                .id(index)
                .transition(.opacity)
                bottomBar
            }
        }
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(index + 1) of \(pages.count)")
                    .font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
                Spacer()
                Button(action: onClose) {
                    Text("Close").font(AppFont.mono(12)).foregroundStyle(AppColor.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close guide")
            }
            DayCompletionBar(cells: pages.indices.map { $0 <= index })
        }
        .padding(.horizontal, AppMetrics.hPadding)
        .padding(.top, 22)
        .padding(.bottom, 28)
    }

    private func pageView(_ page: GuidePage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: page.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColor.accent)
                .frame(width: 52, height: 52)
                .background(Circle().fill(AppColor.surfaceAccent))
                .padding(.bottom, 22)
            Text(page.title)
                .font(AppFont.serif(36)).foregroundStyle(AppColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)
            Text(page.text)
                .font(AppFont.sans(16)).foregroundStyle(AppColor.inkDim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 22)
            if !page.steps.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HRule()
                    ForEach(page.steps.indices, id: \.self) { i in
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text(String(format: "%02d", i + 1))
                                .font(AppFont.mono(11)).foregroundStyle(AppColor.accent)
                            Text((try? AttributedString(markdown: page.steps[i])) ?? AttributedString(page.steps[i]))
                                .font(AppFont.sans(15)).foregroundStyle(AppColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 13)
                        HRule()
                    }
                }
            }
        }
    }

    private var bottomBar: some View {
        BottomBar {
            if index > 0 {
                Button { go(index - 1) } label: {
                    Text("‹ Back")
                        .font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity)
                        .background(Capsule().stroke(AppColor.borderStrong, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 120)
            }
            PrimaryButton(title: index == pages.count - 1 ? "Done" : "Next") {
                if index == pages.count - 1 { onClose() } else { go(index + 1) }
            }
        }
    }

    private func go(_ i: Int) {
        withAnimation(.easeOut(duration: 0.2)) { index = min(max(i, 0), pages.count - 1) }
    }
}

struct GuidePage {
    let icon: String
    let title: String
    let text: String
    /// Short how-tos shown as a numbered list. Markdown bold is allowed.
    var steps: [String] = []

    static let all: [GuidePage] = [
        GuidePage(icon: "sparkles", title: "How Habits works",
                  text: "A walk through everything the app can do, one feature at a time. Tap \"Next\" to go on, or \"Close\" whenever you like. You can open this guide again from Settings."),
        GuidePage(icon: "sun.max", title: "Today",
                  text: "The \"Today\" tab shows every habit due today. The number and bar at the top show how much of today you've kept.",
                  steps: ["Habits still to do are at the top; finished ones move down under \"Done\".",
                          "Switch between \"List\" and \"Grid\" with the toggle. \"Settings\" → \"Default view\" decides which one opens.",
                          "A rest day hides the habit from Today, so it never counts against you."]),
        GuidePage(icon: "checkmark.circle", title: "Checking off",
                  text: "How you log a habit depends on how it's tracked.",
                  steps: ["**Done / not done:** tap the circle. Tap it again to undo.",
                          "**Amount or time:** tap the \"+\" button to add a step. Reaching the goal completes the day.",
                          "**Long-press** an amount or time habit for more: \"Enter amount…\", add a bigger step, or take one off."]),
        GuidePage(icon: "plus", title: "Adding a habit",
                  text: "Tap the green \"+\" in the middle of the tab bar, or \"Add habit\" on the Habits tab.",
                  steps: ["Pick a suggestion to start from, or tap \"Custom habit\" to make your own.",
                          "Give it a name and a category. Add your own categories under \"Change category\".",
                          "Choose \"Build\" for something to do, or \"Quit\" for something to stop."]),
        GuidePage(icon: "slider.horizontal.3", title: "Tracking and goals",
                  text: "Each habit is tracked one of three ways. Pick one under \"Tracking\".",
                  steps: ["**Done:** a simple yes or no each day.",
                          "**Amount:** count anything, like pages, glasses or km, with a daily goal and your own unit.",
                          "**Time:** minutes toward a daily goal, logged by hand or with a timer."]),
        GuidePage(icon: "calendar", title: "Schedule and reminders",
                  text: "Set when a habit is due, so the app only counts the days that matter.",
                  steps: ["**Repeat:** every day, chosen weekdays, a number of times per week, or dates of the month.",
                          "**Starts:** days before the start date don't count in your stats. Tap \"Change date\" to move it.",
                          "**Rest days:** weekdays or single dates off. They never break a streak.",
                          "**Reminder:** a notification at a time you pick, only while the habit is still open."]),
        GuidePage(icon: "doc.text.magnifyingglass", title: "A habit's page",
                  text: "Tap a habit's name on Today or Habits to open its page.",
                  steps: ["Log with the \"+\" and \"−\" buttons, or tap \"enter\" to type an exact amount.",
                          "Time habits have a \"Start timer\" button. The timer keeps running if you leave the app; tap \"Stop\" to log the minutes.",
                          "The chart shows recent days. Tap a bar to see that day's value, and switch how many days it shows.",
                          "Below it: your 30-day rate, current and best streak, and the last 12 months."]),
        GuidePage(icon: "pencil", title: "Editing, archiving, deleting",
                  text: "Everything about a habit can be changed later.",
                  steps: ["Tap \"Edit\" at the top of a habit's page to change its name, goal, schedule or reminder.",
                          "\"Archive habit\" hides it from Today and Stats but keeps its history. Bring it back from \"Habits\" → \"Archived habits\".",
                          "\"Delete habit\" removes it and its whole history for good."]),
        GuidePage(icon: "list.bullet", title: "Habits",
                  text: "The \"Habits\" tab lists every active habit by category, with its goal, schedule and completion rate. Tap one to open it, or scroll to the bottom for \"Archived habits\"."),
        GuidePage(icon: "chart.bar", title: "Statistics",
                  text: "The \"Stats\" tab shows how you're doing over any stretch of time.",
                  steps: ["Pick a range from \"Week\" to \"Year\", or tap \"pick dates\" for your own.",
                          "Tap \"choose habits\" to look at one category, one habit, or any mix.",
                          "Scroll for completion, momentum, your best weekdays, weekends and records.",
                          "If \"Time-of-day stats\" is on in Settings, you also see when you usually do each habit and which ones you do back to back."]),
        GuidePage(icon: "link", title: "Linked misses",
                  text: "Pick exactly two habits under \"choose habits\" to see whether missing one goes with missing the other.",
                  steps: ["The **link score** runs from −1 to 1. Near 0 means no link; near 1 means you tend to miss them together.",
                          "The two cards show how often you missed one habit on days you missed the other, against your usual miss rate."]),
        GuidePage(icon: "bell", title: "Notifications",
                  text: "Choose what the app may remind you about under \"Settings\" → \"Notifications\".",
                  steps: ["\"Habit reminders\" at each habit's own time.",
                          "A \"Morning plan\" of what's due, and an \"Evening check-in\" if something is still open.",
                          "\"Streak rescue\" warns you before a long streak breaks, and a \"Weekly report\" sums up your week."]),
        GuidePage(icon: "externaldrive", title: "Your data",
                  text: "Everything stays on this iPhone; nothing is uploaded. To move to a new phone, make a backup and restore it there.",
                  steps: ["\"Settings\" → \"Back up data\" saves a file with all your habits, history and settings. Save it to Files or iCloud Drive, or AirDrop it.",
                          "On the new phone, go to \"Settings\" → \"Restore from backup\" and pick that file. It replaces what's on that phone.",
                          "\"Export as spreadsheet\" gives you a CSV to open in Numbers or Excel."]),
        GuidePage(icon: "gearshape", title: "Settings",
                  text: "Make the app yours.",
                  steps: ["Tap your name at the top to change it.",
                          "\"Theme\", \"Default view\" and \"Week starts\" switch with a tap.",
                          "\"Time-of-day stats\": keep it on if you tick habits off as you do them, or turn it off if you log everything at once, for example in the evening.",
                          "\"Subscription\" lets you change plan or cancel."]),
        GuidePage(icon: "flag.checkered", title: "You're all set",
                  text: "That's everything. Find this guide again any time under \"Settings\" → \"How Habits works\"."),
    ]
}
