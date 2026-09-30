import SwiftUI

/// A row showing a time of day; tapping it opens a wheel picker.
struct TimeRow: View {
    let title: String
    @Binding var time: String
    var titleFont: Font = AppFont.serif(20)

    @State private var picking = false

    var body: some View {
        DisclosureRow(title: title, titleFont: titleFont, trailing: time, trailingColor: AppColor.accent) {
            picking = true
        }
        .sheet(isPresented: $picking) {
            TimePickerSheet(title: title, initial: time, onSave: { time = $0 }, onClose: { picking = false })
        }
    }
}

struct TimePickerSheet: View {
    let title: String
    var onSave: (String) -> Void
    /// When set, the sheet offers a button to turn the time off, e.g. to remove a reminder.
    var onRemove: (() -> Void)? = nil
    var onClose: () -> Void

    @State private var date: Date

    init(title: String, initial: String, onSave: @escaping (String) -> Void,
         onRemove: (() -> Void)? = nil, onClose: @escaping () -> Void) {
        self.title = title
        self.onSave = onSave
        self.onRemove = onRemove
        self.onClose = onClose
        _date = State(initialValue: ClockTime.date(initial, on: Date()) ?? Date())
    }

    var body: some View {
        ScreenScaffold {
            VStack(spacing: 0) {
                HStack {
                    Text(title).font(AppFont.serif(30)).foregroundStyle(AppColor.ink)
                    Spacer()
                    Button {
                        onSave(ClockTime.string(from: date))
                        onClose()
                    } label: {
                        Text("Done").font(AppFont.mono(12)).foregroundStyle(AppColor.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 22)

                DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "en_GB")) // 24-hour, like the rest of the app

                if let onRemove {
                    SecondaryButton(title: "Turn off", color: AppColor.inkDim, borderColor: AppColor.borderStrong) {
                        onRemove()
                        onClose()
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppMetrics.hPadding)
        }
        .presentationDetents([.height(onRemove == nil ? 320 : 390)])
    }
}
