# EZgate

Simple network control for macOS.

> Control what gets through.

## About

EZgate is an open-source, native macOS menu bar utility for understanding which applications use network bandwidth and controlling whether each application may connect. It is built from scratch in Swift and SwiftUI and does not contain code, assets, wording, or proprietary behavior from commercial products.

The current build contains no simulated traffic. A Network Extension system extension enforces allow/drop rules and reports real per-application byte counters to the menu-bar app through a local App Group. macOS will only activate it after valid Apple signing/provisioning and explicit user approval.

## Features

- Native `MenuBarExtra` panel
- Per-application download/upload totals and current rates
- Allow/Block rules
- Normal, Hotspot, and Restrictive profiles
- Per-profile default policy, including “block all except allowed apps”
- Search by app name, process name, or bundle identifier
- Sorting by total, download, upload, name, or access state
- Pause filtering without deleting rules
- Atomic local profile/rule persistence
- Session and Today totals backed by SQLite
- Wi-Fi/Ethernet/path-cost monitoring with `NWPathMonitor`
- Launch-at-login setting using `SMAppService`
- Real traffic only; an inactive extension produces an honest empty state
- Unit tests for rules, grouping, formatting, context matching, persistence, and statistics

## Screenshots

Screenshots will be added after the visual identity and signed Network Extension onboarding are finalized.

## Requirements

- macOS 14 Sonoma or newer
- Apple Silicon is the primary development architecture
- Xcode 16 or newer; the project is currently verified with Xcode 26.6 and Swift 6.3.3
- XcodeGen only when regenerating `EZgate.xcodeproj` from `project.yml`
- An Apple Developer Program team and Network Extension provisioning for real filtering

## Installation

There is no published binary yet. EZgate remains local by default and this repository is not automatically deployed or published.

## Build from source

Open `EZgate.xcodeproj` and run the `EZgate` scheme, or generate and build from Terminal:

```sh
xcodegen generate
xcodebuild -project EZgate.xcodeproj -scheme EZgate \
  -configuration Debug -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

The unsigned command verifies every target but cannot activate a system extension. Run tests with:

```sh
xcodebuild -project EZgate.xcodeproj -scheme EZgate \
  -configuration Debug -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO test
```

## Network Extension

`EZgateNetworkExtension` is a user-space Content Filter system extension. It loads a read-only rule snapshot from the shared App Group, resolves the macOS source signing identifier from the flow audit token, and returns an allow or drop verdict. If no valid rule snapshot is available it deliberately fails open.

The extension is not silently activated. A signed build must request system-extension activation and filter configuration, and the user must approve the macOS prompts. See `TECHNICAL_FEASIBILITY.md` for the exact constraints.

## Permissions

Real filtering needs:

- Network Extension (`content-filter-provider` in development/App Store profiles)
- System Extension installation in the containing app
- A common App Group for rules and metadata
- User approval in macOS System Settings
- Developer ID-specific `content-filter-provider-systemextension` entitlements for direct distribution

EZgate never asks users to disable SIP, Gatekeeper, or another macOS protection.

## Privacy

There is no account, cloud, telemetry, or analytics. Real traffic metadata remains on the Mac. Packet contents are neither needed nor stored. See `PRIVACY.md`.

## Architecture

The UI, domain logic, persistence, and filtering target are separated. `RuleEngine` does not import SwiftUI or NetworkExtension. See `ARCHITECTURE.md`.

## Known limitations

- Signed activation/configuration of the system extension is not possible without an Apple Developer team and profiles.
- SSID access depends on current macOS privacy authorization; iPhone hotspot identity cannot be guaranteed.
- Content Filters allow or drop traffic but do not provide general bandwidth shaping.
- Temporary rules, quotas, domain history, charts, and export are intentionally outside this MVP.

## Roadmap

See `ROADMAP.md`.

## Contributing

See `CONTRIBUTING.md`. Contributions must use public Apple APIs and must not copy proprietary products or incompatible licensed code.

## License

MIT. See `LICENSE` and `LICENSE_DECISION.md`.
