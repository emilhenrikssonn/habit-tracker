import SwiftUI

enum AppMetrics {
    static let hPadding: CGFloat = 26
    static let cardRadius: CGFloat = 18
    static let tileRadius: CGFloat = 20
    static let inputRadius: CGFloat = 14
    static let smallRadius: CGFloat = 12
    static let pillRadius: CGFloat = 999
}

struct HRule: View {
    var body: some View {
        Rectangle().fill(AppColor.border).frame(height: 1)
    }
}
