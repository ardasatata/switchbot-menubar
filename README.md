# switchbot-menubar

[![CI](https://github.com/ardasatata/switchbot-menubar/actions/workflows/ci.yml/badge.svg)](https://github.com/ardasatata/switchbot-menubar/actions/workflows/ci.yml)

A macOS menu bar app for controlling [SwitchBot](https://www.switch-bot.com) devices, built on
the official [SwitchBot API v1.1](https://github.com/OpenWonderLabs/SwitchBotAPI).

Not affiliated with SwitchBot / Wonderlabs. Each install uses your own Open Token and Secret Key
against your own devices.

## Download

Prebuilt `.dmg` / `.zip` builds are published on the
[Releases page](https://github.com/ardasatata/switchbot-menubar/releases/latest) whenever a
`vX.Y.Z` tag is pushed.

> **These builds are currently unsigned** (no Developer ID / notarization yet). After installing,
> right-click the app → **Open** → **Open**, or run
> `xattr -dr com.apple.quarantine /Applications/switch-bot-menu-bar.app`. Saving a token on first
> launch may show a "wants to use your confidential information" prompt — click **Always Allow**.

## Features

- Lives entirely in the menu bar — no Dock icon, no main window.
- Your Open Token and Secret Key are stored in the macOS Keychain, entered once on first launch,
  changeable any time from Settings.
- **Demo Mode**: try the app with a full set of simulated devices, no SwitchBot account needed.
- Live device list, grouped by category, with controls for everything the API exposes:
  power toggles (Bot, Plug, Plug Mini, Relay Switch, Color Bulb, Strip Light, Ceiling Light, Fan,
  Humidifier, Air Purifier), brightness / color / color-temperature sliders, Curtain / Blind Tilt /
  Roller Shade position, Lock/Unlock, Robot Vacuum start/stop/dock, read-only sensors (Meter,
  Contact, Motion, Water Leak), Scenes, and infrared remotes.
- An unrecognized or brand-new device type still gets working controls — capabilities are
  inferred from whatever fields are actually present in its status response, not just from a
  static table.
- Rate-limit aware: SwitchBot allows 10,000 API calls/day per token. Status is fetched lazily and
  cached, sliders are debounced, and a rolling budget tracker pauses automatic refresh before you
  run out.
- Launch at login, pinned/favorite devices, optional background refresh (off by default).

## Getting an Open Token and Secret Key

1. Open the SwitchBot app on your phone.
2. Go to **Profile → Preferences → About**.
3. Tap the app version number 10 times to reveal **Developer Options**.
4. Tap **Developer Options → Get Token**. (Requires SwitchBot app v6.14+ for the Secret Key.)

Paste both into the app on first launch, or later from **Settings → Replace credentials**.

## Rate limits

The SwitchBot API allows 10,000 calls/day per token, shared with the official SwitchBot app if
you use both. This app targets a self-imposed budget of 8,000/day with a warning at 6,000, and
Settings shows the estimated cost of any background refresh interval before you turn it on.

## Building

Requires Xcode 16+ and a Mac. Open `switch-bot-menu-bar.xcodeproj`, set your own Development Team
under the target's Signing & Capabilities, and build. Deployment target is macOS 14.0 (Sonoma).

## Testing

The `switch-bot-menu-bar` scheme is shared (committed under `xcodeproj/xcshareddata/`), so this
runs unmodified on a fresh clone or in CI:

```
xcodebuild test -project switch-bot-menu-bar.xcodeproj -scheme switch-bot-menu-bar \
  -destination 'platform=macOS' -only-testing:switch-bot-menu-barTests
```

The unit test suite covers request signing (against RFC 4231 HMAC-SHA256 vectors), response
decoding (including unknown/future device types), the device-capability system, per-device-type
command quirks, rate limiting, and the app's optimistic-update state machine — all against a stub
HTTP client, with one integration test proving the real networking stack. No credentials or
network access are required to run it.

## CI/CD

- **`.github/workflows/ci.yml`** — on every push to `main` and every pull request: builds
  Debug and Release, runs the unit tests, runs the UI tests, and runs SwiftLint (`--strict`).
- **`.github/workflows/release.yml`** — on pushing a `vX.Y.Z` tag (or manual dispatch): archives
  a Release build, packages it as a `.dmg` and `.zip`, and publishes a GitHub Release.
- CI and release builds sign ad-hoc via `Config/CI.xcconfig` / `Config/CIRelease.xcconfig` —
  runners have no Developer ID certificate. `Config/Unsigned.entitlements` drops App Sandbox and
  `keychain-access-groups` for release builds so the app can still run and store credentials (see
  the fallback in `Services/CredentialStore.swift`). Local development builds are unaffected and
  keep using the real team/entitlements from the project's build settings.
- To cut a release: `./scripts/release.sh 1.1.0` bumps `MARKETING_VERSION`, commits, and tags —
  then push with `git push origin main --follow-tags` to trigger the release workflow.

## Architecture

- `Models/` — value types: `JSONValue` (a generic JSON representation used for both status
  payloads and the `parameter` field, which is a string for most commands but a nested object for
  Robot Vacuum's `startClean`), `Device`, `DeviceStatus`, `Capability`, `ControlIntent`,
  `DeviceCommand`.
- `Services/` — `RequestSigner` (pure HMAC-SHA256 signing), `SwitchBotClient`, `CredentialStore`
  (Keychain-backed), `DeviceCatalog` (deviceType → capabilities, icon, category), `DeviceQuirks`
  (per-family command parameter formats), `RateLimiter`, `DiskCache`, `DemoHTTPClient`.
- `ViewModels/` — `AppStore`, the single `@Observable` source of truth, owned by the `App` struct
  (not by any view — `MenuBarExtra`'s window-style content view is torn down and recreated on
  every open/close).
- `Views/` — SwiftUI, built around a generic `DeviceRowView` that renders controls by iterating a
  device's capabilities; there is no per-device-type branching in the view layer.

## License

No license file yet — all rights reserved by the author pending a decision. Open an issue if you'd
like to use this code and a license hasn't been added.
