import SwiftUI

enum AppFont {
    static let serifName = "InstrumentSerif-Regular"
    static let serifItalicName = "InstrumentSerif-Italic"
    static let monoName = "JetBrainsMono-Regular"
    static let sansName = "Karla-Regular"

    static func serif(_ size: CGFloat) -> Font { .custom(serifName, size: size) }
    static func serifItalic(_ size: CGFloat) -> Font { .custom(serifItalicName, size: size) }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(monoName, size: size).weight(weight)
    }
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(sansName, size: size).weight(weight)
    }
}

struct SectionLabel: View {
    let text: String
    var color: Color = AppColor.inkMute
    var body: some View {
        Text(text.uppercased())
            .font(AppFont.mono(11, weight: .medium))
            .tracking(11 * 0.16)
            .foregroundStyle(color)
    }
}

struct MetaChip: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(AppFont.mono(10, weight: .medium))
            .tracking(10 * 0.08)
            .foregroundStyle(AppColor.inkMute)
    }
}
