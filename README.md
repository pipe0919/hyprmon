# hyprmon

A macOS menubar widget showing live CPU, RAM, battery, top-5 processes, and Claude Code usage (5-hour and weekly rolling windows). Click the chart icon in the menubar to toggle a glass popover with all metrics.

![screenshot placeholder — add after first build](docs/screenshot.png)

## Install

### Homebrew (recommended)

```bash
brew install pipe0919/tap/hyprmon
open -a Hyprmon
```

To start at login:

```bash
hyprmon --install-agent
```

### From source

```bash
git clone https://github.com/pipe0919/hyprmon
cd hyprmon
./build.sh
open ./build/Hyprmon.app
```

## Configuration

Configuration lives in `~/.config/hyprmon/config.toml`. The file is created with sensible defaults on first run. Edits are picked up live.

See [`examples/config.toml`](examples/config.toml) for the full schema.

Common tweaks:

```toml
opacity = 0.7
accent  = "#F7768E"

[claude]
plan = "max5"          # pro | max5 | max20 | custom
```

For `claude.plan = "custom"`:

```toml
[claude]
plan = "custom"

[claude.limits]
window_5h_tokens     = 500000
window_weekly_tokens = 4000000
```

## What gets measured

| Metric | Source |
|---|---|
| CPU % | `host_statistics(HOST_CPU_LOAD_INFO)` deltas across ticks |
| RAM % | `host_statistics64(HOST_VM_INFO64)`, `(wired+active+compressed)/total` |
| Battery | `IOPowerSources` framework |
| Top processes | `proc_listpids` + `proc_pid_taskinfo`, aggregated by executable name |
| Claude 5h / weekly | Sum of tokens from `~/.claude/projects/**/*.jsonl` over rolling windows |

## Requirements

- macOS 14 (Sonoma) or newer — needed by `@Observable`
- Apple Silicon or Intel (universal binary on Homebrew)

## License

Apache 2.0. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
