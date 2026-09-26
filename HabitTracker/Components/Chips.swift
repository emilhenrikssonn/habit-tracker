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

struct SegmentPill: View {
    let items: [String]
    @Binding var selection: Int
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = i }
                } label: {
                    Text(items[i])
                        .font(AppFont.mono(11, weight: .medium))
                        .tracking(11 * 0.08)
                        .textCase(.uppercase)
                        .foregroundStyle(selection == i ? AppColor.inkOnAccent : AppColor.inkDim)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(selection == i ? AppColor.accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(AppColor.surface))
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
