import SwiftUI

struct ShareHabitScreen: View {
    let habit: Habit
    var onClose: () -> Void

    @State private var kind: ShareKind = .joint
    @State private var canNudge: Bool = true

    var body: some View {
        ScreenScaffold {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        titleBlock
                        modeBlock
                        rowsBlock
                        previewCard
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, AppMetrics.hPadding)
                }
                CancelSaveBar(cancelText: "Cancel", saveText: "Send invite",
                              onCancel: onClose, onSave: onClose)
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: onClose) {
                Text("‹ back").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
            }.buttonStyle(.plain)
            Spacer()
            SectionLabel(text: "share a habit")
        }
        .padding(.horizontal, AppMetrics.hPadding).padding(.top, 18).padding(.bottom, 20)
    }

    private var titleBlock: some View {
        Text("Share with Anna")
            .font(AppFont.serif(36))
            .foregroundStyle(AppColor.ink)
    }

    private var modeBlock: some View {
        HStack(spacing: 12) {
            modeTile(.joint)
            modeTile(.view)
        }
    }

    private func modeTile(_ k: ShareKind) -> some View {
        Button { kind = k } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(k.display)
                    .font(AppFont.serif(21))
                    .foregroundStyle(kind == k ? AppColor.ink : AppColor.inkDim)
                Text(k.caption)
                    .font(AppFont.mono(11))
                    .foregroundStyle(AppColor.inkMute)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: AppMetrics.inputRadius).fill(kind == k ? AppColor.surfaceAccent : AppColor.surface))
            .overlay(RoundedRectangle(cornerRadius: AppMetrics.inputRadius).stroke(kind == k ? AppColor.accentMid : AppColor.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var rowsBlock: some View {
        VStack(spacing: 0) {
            HRule()
            DisclosureRow(title: "Habit", trailing: "\(habit.name) · \(habit.goalString)")
            HRule()
            DisclosureRow(title: "They can see",
                          trailing: kind == .joint ? "Days & streak" : "Days, streak & notes")
            HRule()
            DisclosureRow(title: "Daily summary to Anna", trailing: "21:00")
            HRule()
            ToggleRow(
                title: "Let Anna nudge me",
                subtitle: canNudge ? "Max one reminder per day" : "She can see, but not poke",
                isOn: $canNudge
            )
            HRule()
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Preview")
            VStack(alignment: .leading, spacing: 8) {
                Text(previewTitle)
                    .font(AppFont.serif(21)).foregroundStyle(AppColor.ink)
                Text(previewBody)
                    .font(AppFont.sans(13)).foregroundStyle(AppColor.accentSoft)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).fill(AppColor.surfaceAccent))
            .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).stroke(AppColor.borderAccent, lineWidth: 1))
        }
    }

    private var previewTitle: String {
        kind == .joint
            ? "\(prefsName()) wants to \(habit.name.lowercased()) with you"
            : "\(prefsName()) invited you to watch \(habit.name)"
    }

    private var previewBody: String {
        kind == .joint
            ? "You'll each track your own days. \(prefsName()) sees yours; you see theirs."
            : "Read-only access to their days, streak and notes. Nothing shared back."
    }

    private func prefsName() -> String { "You" }
}
