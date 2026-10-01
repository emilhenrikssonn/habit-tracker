import SwiftUI

struct ScreenScaffold<Content: View>: View {
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .dark
    @ViewBuilder var content: () -> Content
    var body: some View {
        ZStack(alignment: .top) {
            AppColor.bg.ignoresSafeArea()
            content()
        }
        .preferredColorScheme(theme.colorScheme)
    }
}
