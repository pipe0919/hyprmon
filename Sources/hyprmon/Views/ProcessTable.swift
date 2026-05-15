import SwiftUI
import HyprmonCore

struct ProcessTable: View {
    let procs: [ProcessSampler.Aggregate]
    let sortKey: ProcessSampler.SortKey
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
                    Text(display(p))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(theme.fgMuted)
                }
            }
        }
    }

    private func display(_ p: ProcessSampler.Aggregate) -> String {
        switch sortKey {
        case .cpu:    return String(format: "%.1f%%", p.cpuPct * 100)
        case .ram:    return formatBytes(p.rss)
        case .energy: return String(format: "%.0f/s", p.wakeupsPerSec)
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let kb = 1024.0
        let mb = kb * 1024
        let gb = mb * 1024
        let b = Double(bytes)
        if b >= gb { return String(format: "%.1f GB", b / gb) }
        if b >= mb { return String(format: "%.0f MB", b / mb) }
        if b >= kb { return String(format: "%.0f KB", b / kb) }
        return "\(bytes) B"
    }
}
