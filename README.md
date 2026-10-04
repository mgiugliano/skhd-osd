# skhd-osd

A small macOS overlay that shows your [skhd](https://github.com/koekeishiya/skhd) key bindings on a keyboard drawing. Hold your modifier combination ("hyper key") for one second and the overlay appears for a few seconds.

## Features
- Reads `~/.config/skhd/skhdrc`, and re-reads it each time the overlay opens.
- Finds the hyper key by itself: it is the modifier set used by most bindings.
- Labels come from the commands. Override one with a `# osd: My label` comment on the line above a binding.
- Click-through, fades in and out, and shows on the screen under the mouse.

## Build and install
```sh
swift build -c release
cp .build/release/skhd-osd ~/.bin/
codesign -f -s - ~/.bin/skhd-osd
```
Grant Input Monitoring to the binary in System Settings. To start it at login, copy `launchd/local.skhd-osd.plist` to `~/Library/LaunchAgents/`, set the binary path in it, and run `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.skhd-osd.plist`.

## Usage
- `skhd-osd` runs the watcher.
- `skhd-osd --show` shows the overlay once, so it can be bound in skhd.
- `skhd-osd --dump` prints the parsed bindings.

Requires macOS 13 or later and Swift 5.9 or later.

## License
MIT. See [LICENSE](LICENSE).
