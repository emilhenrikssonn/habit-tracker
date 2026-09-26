import Foundation

enum ShareKind: String, Codable {
    case joint, view

    var display: String {
        self == .joint ? "Joint habit" : "View only"
    }

    var caption: String {
        self == .joint ? "you both track it" : "they watch yours"
    }

    var explainer: String {
        self == .joint
            ? "The habit lands on both Today screens with each person's own goal. Both see the other's days and streak."
            : "Read-only access to your days, streak and notes. Nothing shared back."
        }
}

enum InviteStatus: String, Codable {
    case pending, accepted, declined, sent
}

struct Friend: Identifiable, Hashable {
    let id: UUID
    var name: String
    var permission: String
    var initial: String { String(name.prefix(1)) }
}

struct FriendInvite: Identifiable, Hashable {
    let id: UUID
    var fromName: String
    var habitName: String
    var goalText: String
    var explanation: String
    var receivedAgo: String
    var kind: ShareKind
}

struct JointHabit: Identifiable, Hashable {
    let id: UUID
    var habitName: String
    var friendName: String
    var youProgress: String
    var friendProgress: String
}
