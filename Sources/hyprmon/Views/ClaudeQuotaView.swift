import SwiftUI
import HyprmonCore

struct ClaudeQuotaView: View {
    let monitor: ClaudeMonitor
    let cfg: Config.ClaudeOpts
    let theme: Theme

    var body: some View {
        VStack(spacing: 6) {
            if cfg.show5h {
                MetricBar(
                    label: "5H",
                    value: monitor.fraction5h,
                    display: String(format: "%.0f%%", monitor.fraction5h * 100),
                    theme: theme
                )
                if let resetAt = monitor.resetAt5h {
                    HStack {
                        Spacer()
                        Text("resets in \(formatRemaining(from: resetAt))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(theme.fgMuted)
                    }
                }
            }
            if cfg.showWeekly, let frac = monitor.fractionWeekly {
                MetricBar(
                    label: "7D",
                    value: frac,
                    display: String(format: "%.0f%%", frac * 100),
                    theme: theme
                )
                if let resetAt = monitor.resetAtWeekly {
                    HStack {
                        Spacer()
                        Text("resets in \(formatRemaining(from: resetAt))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(theme.fgMuted)
                    }
                }
            }
        }
    }

    private func formatRemaining(from date: Date) -> String {
        let secs = max(date.timeIntervalSinceNow, 0)
        let h = Int(secs) / 3600
        let m = (Int(secs) % 3600) / 60
        if h >= 24 {
            let d = h / 24
            let rh = h % 24
            return "\(d)d \(String(format: "%02d", rh))h"
        }
        return "\(h)h \(String(format: "%02d", m))m"
    }
}
