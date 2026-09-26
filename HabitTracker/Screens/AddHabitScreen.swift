import SwiftUI
import SwiftData

struct AddHabitScreen: View {
    @Environment(\.modelContext) private var ctx
    var onClose: () -> Void

    @State private var filter: HabitCategory? = nil
    @State private var setupEntry: CatalogueEntry? = nil
    @State private var customSetup: Bool = false

    var body: some View {
        ScreenScaffold {
            VStack(alignment: .leading, spacing: 0) {
                header
                chipsRow
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        addCustomRow
                        ForEach(filtered, id: \.id) { entry in
                            HRule()
                            catalogueRow(entry)
                        }
                        HRule()
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, AppMetrics.hPadding)
                }
            }
        }
        .sheet(item: $setupEntry) { entry in
            HabitSetupScreen(prefilled: entry, onClose: { setupEntry = nil; onClose() })
        }
        .sheet(isPresented: $customSetup) {
            HabitSetupScreen(prefilled: nil, onClose: { customSetup = false; onClose() })
        }
    }

    private var filtered: [CatalogueEntry] {
        guard let filter else { return HabitCatalogue.entries }
        return HabitCatalogue.entries.filter { $0.category == filter }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Button(action: onClose) {
                Text("‹ back")
                    .font(AppFont.mono(12))
                    .foregroundStyle(AppColor.inkDim)
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                customSetup = true
            } label: {
                Text("Custom habit")
                    .font(AppFont.mono(12))
                    .foregroundStyle(AppColor.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppMetrics.hPadding)
        .padding(.top, 18)
        .overlay(alignment: .bottomLeading) {
            Text("Add a habit")
                .font(AppFont.serif(36))
                .foregroundStyle(AppColor.ink)
                .padding(.horizontal, AppMetrics.hPadding)
                .offset(y: 40)
        }
        .padding(.bottom, 56)
    }

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(title: "All", isActive: filter == nil) { filter = nil }
                ForEach(HabitCategory.allCases) { cat in
                    CategoryChip(title: cat.display, isActive: filter == cat) { filter = cat }
                }
            }
            .padding(.horizontal, AppMetrics.hPadding)
        }
        .padding(.bottom, 18)
    }

    private var addCustomRow: some View {
        Button {
            customSetup = true
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                    .foregroundStyle(AppColor.outline)
                    .frame(width: 26, height: 26)
                    .overlay(Text("+").font(AppFont.serif(20)).foregroundStyle(AppColor.accent))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add custom habit").font(AppFont.serif(21)).foregroundStyle(AppColor.ink)
                    Text("Start empty and configure yourself")
                        .font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
                }
                Spacer()
                Text("set up ›").font(AppFont.mono(12)).foregroundStyle(AppColor.accent)
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func catalogueRow(_ entry: CatalogueEntry) -> some View {
        Button {
            setupEntry = entry
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.name).font(AppFont.serif(21)).foregroundStyle(AppColor.ink)
                    Text(entry.summary)
                        .font(AppFont.mono(11))
                        .foregroundStyle(AppColor.inkMute)
                }
                Spacer()
                Text("set up ›").font(AppFont.mono(12)).foregroundStyle(AppColor.accent)
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
