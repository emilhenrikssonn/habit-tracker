import SwiftUI

struct CategoryChip: View {
    let title: String
    let isActive: Bool
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.mono(11, weight: .medium))
                .tracking(11 * 0.08)
                .textCase(.uppercase)
                .foregroundStyle(isActive ? AppColor.inkOnAccent : AppColor.inkDim)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isActive {
                            Capsule().fill(AppColor.accent)
                        } else {
                            Capsule().stroke(AppColor.borderStrong, lineWidth: 1)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

struct DayPill: View {
    let letter: String
    let isActive: Bool
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            Text(letter)
                .font(AppFont.mono(12, weight: .medium))
                .foregroundStyle(isActive ? AppColor.accentSoftLight : AppColor.inkDim)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isActive ? AppColor.accentMid : AppColor.surface)
                )
        }
        .buttonStyle(.plain)
    }
}
