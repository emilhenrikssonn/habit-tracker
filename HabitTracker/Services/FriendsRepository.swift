import Foundation
import Observation

@Observable
final class FriendsRepository {
    static let shared = FriendsRepository()

    var friends: [Friend] = [
        Friend(id: UUID(), name: "Marcus", permission: "Sees Read & Exercise · can nudge"),
        Friend(id: UUID(), name: "Anna", permission: "Joint habit only · sees nothing else"),
        Friend(id: UUID(), name: "Sara", permission: "Invite sent · waiting")
    ]

    var invites: [FriendInvite] = [
        FriendInvite(
            id: UUID(),
            fromName: "Anna",
            habitName: "Read 20 pages a day",
            goalText: "Joint habit · Read · 20 pages/day",
            explanation: "You'll each track your own days. She sees yours; you see hers.",
            receivedAgo: "2 h ago",
            kind: .joint
        )
    ]

    var joint: [JointHabit] = [
        JointHabit(
            id: UUID(),
            habitName: "Morning run",
            friendName: "Marcus",
            youProgress: "5/7",
            friendProgress: "6/7"
        )
    ]

    var friendCount: Int { friends.filter { !$0.permission.hasPrefix("Invite sent") }.count }
    var jointCount: Int { joint.count }
}
