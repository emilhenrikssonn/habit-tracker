import SwiftUI

struct DividedRow<Content: View>: View {
    var showTopRule: Bool = true
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            if showTopRule { HRule() }
            content()
        }
    }
}

struct DisclosureRow: View {
    let title: String
    var titleFont: Font = AppFont.serif(20)
    var trailing: String? = nil
    var trailingColor: Color = AppColor.inkDim
    var subtitle: String? = nil
    var showChevron: Bool = true
    var dimmed: Bool = false
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(titleFont)
                        .foregroundStyle(dimmed ? AppColor.inkMute : AppColor.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(AppFont.mono(11))
                            .foregroundStyle(dimmed ? AppColor.dimOff : AppColor.inkMute)
                    }
                }
                Spacer()
                if let trailing {
                    Text(trailing + (showChevron ? " ›" : ""))
                        .font(AppFont.mono(12))
                        .foregroundStyle(dimmed ? AppColor.dimOff : trailingColor)
                } else if showChevron {
                    Text("›").font(AppFont.mono(12)).foregroundStyle(AppColor.inkDim)
                }
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(AppFont.serif(20)).foregroundStyle(AppColor.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.mono(11))
                        .foregroundStyle(AppColor.inkMute)
                }
            }
            Spacer()
            AppToggle(isOn: $isOn)
        }
        .padding(.vertical, 14)
    }
}
