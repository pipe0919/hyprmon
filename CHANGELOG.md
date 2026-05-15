# Changelog

All notable changes to this project will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [SemVer](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-05-15

### Changed
- **Claude usage is now read from Anthropic's OAuth usage API** (the same endpoint Claude Code itself uses) instead of approximated from local JSONL token counts. Numbers are now exact percentages of your plan window, with the real reset time. Default refresh interval is 60 s (was 30 s) because the API is rate-limited.
- The plan (`Pro` / `Max`) is auto-detected from the API response; the `[claude].plan` and `[claude.limits]` TOML options are gone.

### Removed
- `RollingWindow.swift`, `ClaudeUsageReader.swift`, `PlanLimits.swift` (all replaced by `ClaudeAPIClient.swift`).
- `[claude].plan`, `[claude.limits.window_5h_tokens]`, `[claude.limits.window_weekly_tokens]` config keys.

### How auth works
Token is auto-discovered: `CLAUDE_TOKEN` env var → macOS Keychain (`Claude Code-credentials`) → `~/.claude/.credentials.json`. If you've run `claude login`, it works with no extra setup.

## [0.3.0] - 2026-05-15

### Added
- **Auto-start at login.** First launch installs a LaunchAgent so hyprmon comes back after reboot. Toggle from the menubar item's right-click menu.
- **Theme picker** in the right-click menu. Six presets (Blue, Pink, Green, Orange, Purple, Cyan) write the accent color to `config.toml` and apply live. Section headers now use the accent color so theme changes are immediately visible.
- **`Open config file…`** entry in the right-click menu for power users.

### Changed
- **Claude section auto-hides** if Claude Code is not installed (i.e. `~/.claude/projects/` is missing).
- LaunchAgent now points to the stable Homebrew bin symlink (`/opt/homebrew/bin/hyprmon`) when running from a Cellar path, so version upgrades don't break the agent.

## [0.2.0] - 2026-05-15

### Changed
- **Replaced desktop-level panel with a menubar item.** The widget now lives in the macOS menubar as a small chart icon; click it to toggle a popover with all metrics. The previous desktop-level NSPanel was useless because windows kept covering it.
- **Top Processes** can now be sorted by CPU, RAM, or Energy (interrupt + idle wakeups, similar to Activity Monitor's Energy column). Toggle with the segmented control in the popover; default comes from `processes.sort_by` in `config.toml` (`cpu` | `ram` | `energy`).

### Removed
- `corner` and `margin` TOML options (no longer applicable to a popover).

## [0.1.0] - 2026-05-15

### Added
- Live CPU, RAM, and battery readouts on a desktop-level floating panel.
- Top 5 processes (aggregated by executable name).
- Claude Code usage tracker: 5-hour and weekly rolling windows for Pro/Max5/Max20/custom plans.
- TOML configuration at `~/.config/hyprmon/config.toml` with live reload via FSEvents.
- `hyprmon --install-agent` / `--uninstall-agent` for login startup.
- Homebrew distribution via `pipe0919/homebrew-tap`.
- Universal binary (arm64 + x86_64) via `./build.sh --universal`.
