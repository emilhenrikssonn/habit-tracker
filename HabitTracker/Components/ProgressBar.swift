import SwiftUI

struct ThinBar: View {
    let progress: Double // 0..1
    var height: CGFloat = 4
    var track: Color = AppColor.border
    var fill: Color = AppColor.accent
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().fill(track)
                Rectangle().fill(fill)
                    .frame(width: max(0, min(1, progress)) * g.size.width)
            }
        }
        .frame(height: height)
        .clipShape(Rectangle())
    }
}

struct DayCompletionBar: View {
    let cells: [Bool]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(cells.indices, id: \.self) { i in
                Rectangle()
                    .fill(cells[i] ? AppColor.accent : AppColor.borderStrong)
                    .frame(height: 6)
            }
        }
    }
}
