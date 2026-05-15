# Changelog

All notable changes to this project will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [SemVer](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-05-15

### Added
- Live CPU, RAM, and battery readouts on a desktop-level floating panel.
- Top 5 processes (aggregated by executable name).
- Claude Code usage tracker: 5-hour and weekly rolling windows for Pro/Max5/Max20/custom plans.
- TOML configuration at `~/.config/hyprmon/config.toml` with live reload via FSEvents.
- `hyprmon --install-agent` / `--uninstall-agent` for login startup.
- Homebrew distribution via `pipe0919/homebrew-tap`.
- Universal binary (arm64 + x86_64) via `./build.sh --universal`.
