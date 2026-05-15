import SwiftUI
import HyprmonCore

struct ContentView: View {
    let system: SystemSampler
    let claude: ClaudeMonitor
    let cfg: Config
    let theme: Theme

    @State private var sortKey: ProcessSampler.SortKey

    init(system: SystemSampler, claude: ClaudeMonitor, cfg: Config, theme: Theme) {
        self.system = system
        self.claude = claude
        self.cfg = cfg
        self.theme = theme
        let initial: ProcessSampler.SortKey
        switch cfg.processes.sortBy {
        case .cpu:    initial = .cpu
        case .ram:    initial = .ram
        case .energy: initial = .energy
        }
        _sortKey = State(initialValue: initial)
    }

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
                HStack {
                    SectionHeader(title: "Top Processes", theme: theme)
                    Spacer()
                    Picker("", selection: $sortKey) {
                        Text("CPU").tag(ProcessSampler.SortKey.cpu)
                        Text("RAM").tag(ProcessSampler.SortKey.ram)
                        Text("Energy").tag(ProcessSampler.SortKey.energy)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.mini)
                    .fixedSize()
                    .onChange(of: sortKey) { _, newValue in
                        system.setSortKey(newValue)
                    }
                }
                ProcessTable(procs: system.topProcs, sortKey: sortKey, theme: theme)
            }

            if cfg.modules.claude, claude.isAvailable {
                Divider().background(theme.surface)
                SectionHeader(title: "Claude", theme: theme)
                ClaudeQuotaView(monitor: claude, cfg: cfg.claude, theme: theme)
            }
        }
        .padding(16)
        .frame(width: 340, alignment: .leading)
    }
}
