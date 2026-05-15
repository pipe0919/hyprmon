import SwiftUI
import HyprmonCore

struct ContentView: View {
    let system: SystemSampler
    let claude: ClaudeMonitor
    let cfg: Config
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "HYPRMON", theme: theme)

            if cfg.modules.cpu || cfg.modules.ram || cfg.modules.battery {
                SectionHeader(title: "System", theme: theme)
                VStack(spacing: 6) {
                    if cfg.modules.cpu {
                        MetricBar(label: "CPU", value: system.cpu,
                                  display: String(format: "%.0f%%", system.cpu * 100), theme: theme)
                    }
                    if cfg.modules.ram {
                        MetricBar(label: "RAM", value: system.ram,
                                  display: String(format: "%.0f%%", system.ram * 100), theme: theme)
                    }
                    if cfg.modules.battery, system.battery.isPresent {
                        BatteryRow(state: system.battery, theme: theme)
                    }
                }
            }

            if cfg.modules.processes, !system.topProcs.isEmpty {
                Divider().background(theme.surface)
                SectionHeader(title: "Top Processes", theme: theme)
                ProcessTable(procs: system.topProcs, theme: theme)
            }

            if cfg.modules.claude {
                Divider().background(theme.surface)
                SectionHeader(title: "Claude", theme: theme)
                ClaudeQuotaView(monitor: claude, cfg: cfg.claude, theme: theme)
            }
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
    }
}
