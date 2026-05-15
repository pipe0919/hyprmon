import SwiftUI
import HyprmonCore

struct ProcessTable: View {
    let procs: [ProcessSampler.Aggregate]
    let theme: Theme

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(procs.enumerated()), id: \.offset) { _, p in
                HStack {
                    Text(p.name)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.fgPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 4)
                    Text(String(format: "%.1f%%", p.cpuPct * 100))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(theme.fgMuted)
                }
            }
        }
    }
}
