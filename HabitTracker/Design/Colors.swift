import SwiftUI

enum AppColor {
    static let bg = Color(hex: 0x0D100E)
    static let surface = Color(hex: 0x171B19)
    static let surfaceAccent = Color(hex: 0x132018)
    static let border = Color(hex: 0x1E2421)
    static let borderStrong = Color(hex: 0x252B27)
    static let borderAccent = Color(hex: 0x23392C)
    static let accentMid = Color(hex: 0x2F4A3C)
    static let accent = Color(hex: 0x58C98C)
    static let ink = Color(hex: 0xF2F5F3)
    static let inkDim = Color(hex: 0x8A938D)
    static let inkMute = Color(hex: 0x7C857F)
    static let inkOnAccent = Color(hex: 0x0D100E)
    static let outline = Color(hex: 0x3C4642)
    static let accentSoft = Color(hex: 0x9FB3A7)
    static let accentSoft2 = Color(hex: 0x93AB9D)
    static let accentSoftLight = Color(hex: 0xD8ECE1)
    static let accentSoftStrong = Color(hex: 0x9FD9B8)
    static let barTrack = Color(hex: 0x232A26)
    static let calendarKept = Color(hex: 0x1C3527)
    static let dimOff = Color(hex: 0x4F5A55)
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xff) / 255
        let g = Double((hex >> 8) & 0xff) / 255
        let b = Double(hex & 0xff) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
