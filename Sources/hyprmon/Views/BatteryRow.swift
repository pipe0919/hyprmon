import SwiftUI
import HyprmonCore

struct BatteryRow: View {
    let state: BatteryState
    let theme: Theme

    private var fillColor: Color {
        switch state.percent {
        case ..<20:  return theme.danger
        case ..<50:  return theme.warn
        default:     return theme.ok
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("BAT")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.fgMuted)
                .frame(width: 28, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(theme.trackBg)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(fillColor)
                        .frame(width: proxy.size.width * Double(state.percent) / 100.0, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: state.percent)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 14)

            Text("\(state.percent)%")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.fgPrimary)
                .frame(width: 36, alignment: .trailing)

            Text(state.isCharging ? "⚡" : "")
                .font(.system(size: 11))
                .foregroundStyle(theme.accent)
                .frame(width: 10, alignment: .leading)
        }
        .frame(height: 16)
    }
}
