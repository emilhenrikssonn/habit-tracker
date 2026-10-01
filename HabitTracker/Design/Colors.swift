import SwiftUI
import UIKit

/// Dark is the default. Light keeps the same greens, darkened where they sit on white.
enum AppTheme: String, CaseIterable, Identifiable {
    case dark, light
    static let storageKey = "appTheme"
    var id: String { rawValue }
    var display: String { self == .dark ? "Dark" : "Light" }
    var colorScheme: ColorScheme { self == .dark ? .dark : .light }
}

enum AppColor {
    static let bg = themed(dark: 0x0D100E, light: 0xFFFFFF)
    static let surface = themed(dark: 0x171B19, light: 0xF4F7F5)
    static let surfaceAccent = themed(dark: 0x132018, light: 0xE6F4EC)
    static let border = themed(dark: 0x1E2421, light: 0xE3E8E5)
    static let borderStrong = themed(dark: 0x252B27, light: 0xD3DAD6)
    static let borderAccent = themed(dark: 0x23392C, light: 0xB9DEC9)
    static let accentMid = themed(dark: 0x2F4A3C, light: 0xA9DCC0)
    static let accent = themed(dark: 0x58C98C, light: 0x1E9460)
    static let ink = themed(dark: 0xF2F5F3, light: 0x0D100E)
    static let inkDim = themed(dark: 0x8A938D, light: 0x5C665F)
    static let inkMute = themed(dark: 0x7C857F, light: 0x6B756E)
    static let inkOnAccent = themed(dark: 0x0D100E, light: 0xFFFFFF)
    static let outline = themed(dark: 0x3C4642, light: 0xB4BEB8)
    static let accentSoft = themed(dark: 0x9FB3A7, light: 0x4F6B5B)
    static let accentSoft2 = themed(dark: 0x93AB9D, light: 0x5A7868)
    static let accentSoftLight = themed(dark: 0xD8ECE1, light: 0x14532F)
    static let accentSoftStrong = themed(dark: 0x9FD9B8, light: 0x2E7D54)
    static let barTrack = themed(dark: 0x232A26, light: 0xE4E9E6)
    static let calendarKept = themed(dark: 0x1C3527, light: 0xCDEBD9)
    static let dimOff = themed(dark: 0x4F5A55, light: 0xB0B8B3)

    private static func themed(dark: UInt32, light: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .light ? UIColor(Color(hex: light)) : UIColor(Color(hex: dark)) })
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xff) / 255
        let g = Double((hex >> 8) & 0xff) / 255
        let b = Double(hex & 0xff) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
