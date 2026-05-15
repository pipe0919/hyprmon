# Contributing to hyprmon

Thanks for your interest! hyprmon is small and focused on doing one thing well: showing system + Claude usage in a tasteful desktop widget.

## Dev setup

Requirements: macOS 13+, Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/pipe0919/hyprmon
cd hyprmon
swift test            # run unit tests
./build.sh            # build Hyprmon.app into ./build/
open ./build/Hyprmon.app
```

## Style

- Swift 5.9+ idioms; prefer `@Observable` over `ObservableObject` where possible.
- Pure logic goes in `Sources/HyprmonCore/`. View / AppKit code in `Sources/hyprmon/`.
- All new logic in `HyprmonCore` needs unit tests.

## Scope

Out of scope for v1.x:
- GPU / network / disk metrics
- Notifications / alerts
- Multiple themes
- A native Preferences window (TOML only)

If you want one of these, open an issue first so we can discuss.
