import SwiftUI

struct ScreenScaffold<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        ZStack(alignment: .top) {
            AppColor.bg.ignoresSafeArea()
            content()
        }
        .preferredColorScheme(.dark)
    }
}
