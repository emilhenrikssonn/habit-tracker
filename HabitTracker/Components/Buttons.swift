import SwiftUI

struct PrimaryButton: View {
    let title: String
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.serif(20))
                .foregroundStyle(AppColor.inkOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(AppColor.accent, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct SecondaryButton: View {
    let title: String
    var color: Color = AppColor.accent
    var borderColor: Color = AppColor.accentMid
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.mono(12, weight: .medium))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    Capsule().stroke(borderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct BottomBar<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            HRule()
            HStack(spacing: 12) {
                content()
            }
            .padding(.horizontal, AppMetrics.hPadding)
            .padding(.top, 14)
            .padding(.bottom, 26)
        }
        .background(AppColor.bg)
    }
}

struct CancelSaveBar: View {
    let cancelText: String
    let saveText: String
    var onCancel: () -> Void = {}
    var onSave: () -> Void = {}
    var body: some View {
        BottomBar {
            Button(action: onCancel) {
                Text(cancelText)
                    .font(AppFont.mono(12))
                    .foregroundStyle(AppColor.inkDim)
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule().stroke(AppColor.borderStrong, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            PrimaryButton(title: saveText, action: onSave)
                .frame(maxWidth: .infinity)
        }
    }
}
