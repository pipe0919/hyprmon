import SwiftUI
import HyprmonCore

struct MetricBar: View {
    let label: String
    let value: Double
    let display: String
    let theme: Theme
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.fgMuted)
                .frame(width: 28, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(theme.trackBg)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(theme.heatColor(for: value))
                        .frame(width: max(0, min(value, 1)) * proxy.size.width, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: value)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 14)

            Text(display)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.fgPrimary)
                .frame(width: 36, alignment: .trailing)

            if let trailing {
                Text(trailing)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.accent)
                    .frame(width: 10, alignment: .leading)
            } else {
                Color.clear.frame(width: 10)
            }
        }
        .frame(height: 16)
    }
}
