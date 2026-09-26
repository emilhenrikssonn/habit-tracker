import SwiftUI
import SwiftData

struct FriendsScreen: View {
    @Query(sort: [SortDescriptor(\Habit.sortIndex)]) private var habits: [Habit]
    let repo = FriendsRepository.shared
    var onShare: (Habit) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBlock
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    addFriendRow
                    ForEach(repo.invites) { invite in
                        inviteCard(invite).padding(.top, 18)
                    }
                    SectionLabel(text: "Joint habits", color: AppColor.inkMute)
                        .padding(.top, 24).padding(.bottom, 6)
                    ForEach(repo.joint) { j in
                        HRule()
                        jointRow(j)
                    }
                    HRule()
                    SectionLabel(text: "Friends")
                        .padding(.top, 24).padding(.bottom, 6)
                    ForEach(repo.friends) { f in
                        HRule()
                        friendRow(f)
                    }
                    HRule()
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, AppMetrics.hPadding)
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Friends").font(AppFont.serif(40)).foregroundStyle(AppColor.ink)
            Text("\(repo.friendCount) friends · \(repo.jointCount) joint habit")
                .font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppMetrics.hPadding).padding(.top, 20).padding(.bottom, 18)
    }

    private var addFriendRow: some View {
        Button {} label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [3,3]))
                    .foregroundStyle(AppColor.outline)
                    .frame(width: 26, height: 26)
                    .overlay(Text("+").font(AppFont.serif(20)).foregroundStyle(AppColor.accent))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add a friend").font(AppFont.serif(21)).foregroundStyle(AppColor.ink)
                    Text("Share a link or find by username")
                        .font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
                }
                Spacer()
                Text("›").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
            }
            .padding(.vertical, 15).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func inviteCard(_ invite: FriendInvite) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("INVITE").font(AppFont.mono(10, weight: .medium)).tracking(0.8)
                    .foregroundStyle(AppColor.accent)
                Spacer()
                Text(invite.receivedAgo).font(AppFont.mono(10)).foregroundStyle(AppColor.inkMute)
            }
            Text("\(invite.fromName) wants to \(invite.habitName.lowercased()) with you")
                .font(AppFont.serif(22)).foregroundStyle(AppColor.ink)
            Text(invite.explanation)
                .font(AppFont.sans(13)).foregroundStyle(AppColor.accentSoft)
            HStack(spacing: 10) {
                Button {} label: {
                    Text("Accept")
                        .font(AppFont.mono(12)).foregroundStyle(AppColor.inkOnAccent)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Capsule().fill(AppColor.accent))
                }.buttonStyle(.plain)
                Button {} label: {
                    Text("Decline")
                        .font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Capsule().stroke(AppColor.borderStrong, lineWidth: 1))
                }.buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).fill(AppColor.surfaceAccent))
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).stroke(AppColor.borderAccent, lineWidth: 1))
    }

    private func jointRow(_ j: JointHabit) -> some View {
        Button {
            if let habit = habits.first { onShare(habit) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(j.habitName) · with \(j.friendName)")
                        .font(AppFont.serif(21)).foregroundStyle(AppColor.ink)
                    Text("You \(j.youProgress) · \(j.friendName) \(j.friendProgress) this week")
                        .font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
                }
                Spacer()
                Text("nudge ›").font(AppFont.mono(12)).foregroundStyle(AppColor.accent)
            }
            .padding(.vertical, 15).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func friendRow(_ f: Friend) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(AppColor.accentMid).frame(width: 34, height: 34)
                Text(f.initial).font(AppFont.serif(19)).foregroundStyle(AppColor.accentSoftLight)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(f.name).font(AppFont.serif(21)).foregroundStyle(AppColor.ink)
                Text(f.permission).font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
                    .lineLimit(1)
            }
            Spacer()
            Text("›").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
        }
        .padding(.vertical, 12)
    }
}
