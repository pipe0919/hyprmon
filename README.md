# hyprmon

A macOS menubar widget showing live CPU, RAM, battery, top-5 processes, and Claude Code usage (5-hour and weekly rolling windows). Click the chart icon in the menubar to toggle a glass popover with all metrics.

![screenshot placeholder — add after first build](docs/screenshot.png)

## Install

### Homebrew (recommended)

```bash
brew install pipe0919/tap/hyprmon
open -a Hyprmon
```

hyprmon installs a LaunchAgent automatically on first launch so it comes back after reboot. Right-click the menubar icon → `Launch at Login` to toggle off, or run `hyprmon --uninstall-agent`.

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
```

You can also pick a theme without editing TOML — right-click the menubar icon → `Theme`.

The Claude section auto-detects your plan and reads exact usage from Anthropic's OAuth API. The token is auto-discovered from your macOS Keychain or `~/.claude/.credentials.json` — no manual setup if you've run `claude login`.

To toggle visibility of the 5-hour or weekly bars:

```toml
[claude]
show_5h     = true
show_weekly = true
```

## What gets measured

| Metric | Source |
|---|---|
| CPU % | `host_statistics(HOST_CPU_LOAD_INFO)` deltas across ticks |
| RAM % | `host_statistics64(HOST_VM_INFO64)`, `(wired+active+compressed)/total` |
| Battery | `IOPowerSources` framework |
| Top processes | `proc_listpids` + `proc_pid_taskinfo`, aggregated by executable name |
| Claude 5h / weekly | Anthropic's OAuth usage API (`/api/oauth/usage`) — exact utilization from your subscription |

## Requirements

- macOS 14 (Sonoma) or newer — needed by `@Observable`
- Apple Silicon or Intel (universal binary on Homebrew)

## License

Apache 2.0. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
