import SwiftUI
import SwiftData

/// First-launch flow: name, a short tour, interests, first habits and notification choices.
struct OnboardingScreen: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: [SortDescriptor(\Habit.sortIndex)]) private var habits: [Habit]
    @Bindable var prefs: AppPrefs

    private enum Step: Int, CaseIterable {
        case welcome, name, tour, interests, habits, notifications, done
    }

    @State private var step: Step = {
        if let arg = ProcessInfo.processInfo.environment["ONBOARDING_STEP"],
           let i = Int(arg), let s = Step(rawValue: i) {
            return s
        }
        return .welcome
    }()
    @State private var name = ""
    @State private var interests: Set<HabitCategory> = []
    @State private var picked: Set<String> = []
    @State private var customSetup = false
    @State private var reminderTime = "08:00"
    @FocusState private var nameFocused: Bool

    var body: some View {
        ScreenScaffold {
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        content
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppMetrics.hPadding)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                .id(step)
                .transition(.opacity)
                bottomBar
            }
        }
        .sheet(isPresented: $customSetup) {
            HabitSetupScreen(prefilled: nil, onClose: { customSetup = false })
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack(spacing: 16) {
            Button { go(to: Step(rawValue: step.rawValue - 1)) } label: {
                Text("‹ back").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
            }
            .buttonStyle(.plain)
            .opacity(step == .welcome || step == .done ? 0 : 1)
            .disabled(step == .welcome || step == .done)

            DayCompletionBar(cells: Step.allCases.dropFirst().map { $0.rawValue <= step.rawValue })
        }
        .padding(.horizontal, AppMetrics.hPadding)
        .padding(.top, 18)
        .padding(.bottom, 28)
    }

    @ViewBuilder
    private var bottomBar: some View {
        switch step {
        case .welcome:
            BottomBar { PrimaryButton(title: "Get started") { go(to: .name) } }
        case .name:
            BottomBar { PrimaryButton(title: "Continue") { nameFocused = false; go(to: .tour) } }
        case .tour:
            BottomBar { PrimaryButton(title: "Got it") { go(to: .interests) } }
        case .interests:
            BottomBar {
                PrimaryButton(title: interests.isEmpty ? "Show me everything" : "Continue") { go(to: .habits) }
            }
        case .habits:
            BottomBar {
                PrimaryButton(title: habitCount == 0 ? "Skip for now" : "Continue with \(count(habitCount))") {
                    go(to: .notifications)
                }
            }
        case .notifications:
            VStack(spacing: 0) {
                HRule()
                VStack(spacing: 12) {
                    PrimaryButton(title: prefs.enabledNotificationCount == 0 ? "Continue" : "Allow notifications") {
                        Task {
                            if prefs.enabledNotificationCount > 0 {
                                await NotificationScheduler.requestPermission()
                            }
                            go(to: .done)
                        }
                    }
                    if prefs.enabledNotificationCount > 0 {
                        Button {
                            prefs.disableAllNotifications()
                            go(to: .done)
                        } label: {
                            Text("Not now").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppMetrics.hPadding)
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
            .background(AppColor.bg)
        case .done:
            BottomBar { PrimaryButton(title: "Start", action: finish) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcome
        case .name: namePage
        case .tour: tour
        case .interests: interestsPage
        case .habits: habitsPage
        case .notifications: notificationsPage
        case .done: donePage
        }
    }

    private func title(_ text: String, _ subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(AppFont.serif(40))
                .foregroundStyle(AppColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(AppFont.sans(15))
                    .foregroundStyle(AppColor.inkDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 28)
    }

    // MARK: Pages

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 60)
            Text("Habits")
                .font(AppFont.serif(72))
                .foregroundStyle(AppColor.ink)
            Text("Small things, kept daily.")
                .font(AppFont.serifItalic(28))
                .foregroundStyle(AppColor.accent)
            Text("Build the habits you want and quit the ones you don't, one day at a time. Everything you track stays on this iPhone.")
                .font(AppFont.sans(16))
                .foregroundStyle(AppColor.inkDim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }
    }

    private var namePage: some View {
        VStack(alignment: .leading, spacing: 0) {
            title("What should we call you?", "Shown in Settings. You can change it any time.")
            TextField("", text: $name, prompt: Text("Your name").foregroundStyle(AppColor.inkDim))
                .font(AppFont.serif(34))
                .foregroundStyle(AppColor.ink)
                .textContentType(.givenName)
                .submitLabel(.continue)
                .focused($nameFocused)
                .onSubmit { go(to: .tour) }
            HRule().padding(.top, 8)
        }
        .onAppear { nameFocused = true }
    }

    private var tour: some View {
        VStack(alignment: .leading, spacing: 0) {
            title("How it works")
            tourRow(icon: "sun.max", title: "Today",
                    text: "Everything due today. Tap the circle to mark a habit done, or +1 to log an amount.")
            tourRow(icon: "plus", title: "Add habits", accent: true,
                    text: "The + in the middle of the tab bar adds a habit. Pick a suggestion or make your own.")
            tourRow(icon: "list.bullet", title: "Habits",
                    text: "All your habits by category. Open one to log more, run a timer, or edit its goal, schedule and reminder.")
            tourRow(icon: "chart.bar", title: "Stats",
                    text: "Completion, streaks and trends over the last week, month or year.")
            tourRow(icon: "gearshape", title: "Settings",
                    text: "Your name and notifications. Anything you choose now can be changed there later.")
        }
    }

    private func tourRow(icon: String, title: String, accent: Bool = false, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent ? AppColor.inkOnAccent : AppColor.accent)
                .frame(width: 38, height: 38)
                .background(Circle().fill(accent ? AppColor.accent : AppColor.surfaceAccent))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(AppFont.serif(22)).foregroundStyle(AppColor.ink)
                Text(text)
                    .font(AppFont.sans(14))
                    .foregroundStyle(AppColor.inkDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 22)
    }

    private var interestsPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            title("What do you want to work on?", "Pick as many as you like, and we'll suggest habits to start with.")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(HabitCategory.allCases) { category in
                    interestTile(category)
                }
            }
        }
    }

    private func interestTile(_ category: HabitCategory) -> some View {
        let on = interests.contains(category)
        return Button {
            if on { interests.remove(category) } else { interests.insert(category) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(category.display).font(AppFont.serif(24))
                        .foregroundStyle(on ? AppColor.ink : AppColor.inkDim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    CheckCircle(done: on)
                }
                Spacer(minLength: 8)
                Text(category.examples)
                    .font(AppFont.mono(10))
                    .foregroundStyle(AppColor.inkMute)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: AppMetrics.tileRadius)
                .fill(on ? AppColor.surfaceAccent : AppColor.surface))
            .overlay(RoundedRectangle(cornerRadius: AppMetrics.tileRadius)
                .stroke(on ? AppColor.accentMid : AppColor.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var suggestions: [(HabitCategory, [CatalogueEntry])] {
        HabitCategory.allCases
            .filter { interests.isEmpty || interests.contains($0) }
            .map { category in (category, HabitCatalogue.entries.filter { $0.category == category }) }
    }

    private var habitCount: Int { picked.count + habits.count }

    private var habitsPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            title("Pick a few to start", "Two or three is plenty. You can change goals and schedules later.")
            addOwnRow
            if !habits.isEmpty {
                SectionLabel(text: "Your own", color: AppColor.accent).padding(.top, 24).padding(.bottom, 6)
                ForEach(habits) { habit in
                    HRule()
                    HStack(spacing: 14) {
                        CheckCircle(done: true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(habit.name).font(AppFont.serif(21)).foregroundStyle(AppColor.ink)
                            Text("\(habit.categoryName) · \(habit.goalString.lowercased())")
                                .font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 13)
                }
                HRule()
            }
            ForEach(suggestions, id: \.0) { category, entries in
                SectionLabel(text: category.display).padding(.top, 24).padding(.bottom, 6)
                ForEach(entries) { entry in
                    HRule()
                    suggestionRow(entry)
                }
                HRule()
            }
        }
    }

    private var addOwnRow: some View {
        Button { customSetup = true } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                    .foregroundStyle(AppColor.outline)
                    .frame(width: 22, height: 22)
                    .overlay(Text("+").font(AppFont.serif(18)).foregroundStyle(AppColor.accent))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add your own").font(AppFont.serif(21)).foregroundStyle(AppColor.ink)
                    Text("Name it and choose how to track it")
                        .font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
                }
                Spacer()
                Text("set up ›").font(AppFont.mono(12)).foregroundStyle(AppColor.accent)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func suggestionRow(_ entry: CatalogueEntry) -> some View {
        let on = picked.contains(entry.name)
        return Button {
            if on { picked.remove(entry.name) } else { picked.insert(entry.name) }
        } label: {
            HStack(spacing: 14) {
                CheckCircle(done: on)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.name).font(AppFont.serif(21))
                        .foregroundStyle(on ? AppColor.ink : AppColor.inkDim)
                    Text(entry.goalString).font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
                }
                Spacer()
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var notificationsPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            title("Stay on track", "Choose what you'd like to hear about. You can change this any time in Settings → Notifications.")
            NotificationOptions(prefs: prefs, habitReminderTime: $reminderTime)
        }
    }

    private var donePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 60)
            Text(greeting)
                .font(AppFont.serif(48))
                .foregroundStyle(AppColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(habitCount == 0
                 ? "Add your first habit with the + button whenever you're ready."
                 : "You'll find your \(count(habitCount)) in the Today tab.")
                .font(AppFont.serifItalic(24))
                .foregroundStyle(AppColor.accent)
                .fixedSize(horizontal: false, vertical: true)
            Text("Everything you track stays on this iPhone. Nothing is uploaded or shared.")
                .font(AppFont.sans(15))
                .foregroundStyle(AppColor.inkDim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }
    }

    private var greeting: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "You're all set." : "You're all set, \(trimmed)."
    }

    // MARK: Actions

    private func go(to next: Step?) {
        guard let next else { return }
        withAnimation(.easeOut(duration: 0.2)) { step = next }
    }

    private func count(_ n: Int) -> String { n == 1 ? "1 habit" : "\(n) habits" }

    private func finish() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        prefs.displayName = trimmed.isEmpty ? "You" : trimmed

        var sortIndex = (habits.map(\.sortIndex).max() ?? -1) + 1
        for entry in HabitCatalogue.entries where picked.contains(entry.name) {
            let habit = entry.makeHabit(sortIndex: sortIndex)
            if prefs.habitRemindersEnabled { habit.reminder = reminderTime }
            ctx.insert(habit)
            sortIndex += 1
        }

        withAnimation(.easeOut(duration: 0.25)) { prefs.hasOnboarded = true }
        try? ctx.save()
        Task { await NotificationScheduler.reschedule(in: ctx) }
    }
}

private extension HabitCategory {
    var examples: String {
        switch self {
        case .health: return "Water, sleep, vitamins"
        case .movement: return "Exercise, steps, stretching"
        case .mind: return "Reading, meditation, journaling"
        case .focus: return "Deep work, planning, learning"
        case .quit: return "Sugar, screens, social media"
        }
    }
}
