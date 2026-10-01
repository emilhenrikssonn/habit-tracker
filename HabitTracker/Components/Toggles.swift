import SwiftUI

struct AppToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? AppColor.accentMid : AppColor.borderStrong)
                    .frame(width: 50, height: 30)
                Circle()
                    .fill(isOn ? AppColor.accent : AppColor.inkMute)
                    .frame(width: 24, height: 24)
                    .padding(3)
            }
        }
        .buttonStyle(.plain)
    }
}

struct CheckCircle: View {
    let done: Bool
    var body: some View {
        if done {
            ZStack {
                Circle().fill(AppColor.accentMid)
                Text("✓")
                    .font(AppFont.mono(12, weight: .medium))
                    .foregroundStyle(AppColor.accent)
            }
            .frame(width: 20, height: 20)
        } else {
            Circle()
                .stroke(AppColor.outline, lineWidth: 1.5)
                .frame(width: 22, height: 22)
                .contentShape(Circle())
        }
    }
}
