# Contributing

EZgate welcomes focused contributions that preserve native macOS behavior, low resource use, transparency, and privacy.

## Setup

1. Install Xcode and XcodeGen.
2. Run `xcodegen generate`.
3. Build the `EZgate` scheme with signing disabled for UI and domain development. To run the real filter, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set your own Team ID; never commit it.
4. Run the unit tests before submitting changes.

## Design rules

- Keep `RuleEngine` and models independent of SwiftUI and NetworkExtension.
- Prefer async/await, actors, protocols, and dependency injection.
- Avoid global mutable state, force unwraps, force tries, aggressive polling, and per-packet UI mutations.
- Do not add simulated traffic to production UI or present generated values as captured traffic.
- Use OSLog without packet content, secrets, tokens, or unnecessary URLs.
- Add tests for rule precedence, grouping, persistence, and migrations.
- Use only public Apple APIs. Never require disabling SIP or Gatekeeper.

## Licensing and originality

Contributions are made under MIT. Do not paste GPL-incompatible code into the repository. Do not copy proprietary code, resources, UI, text, or distinctive behavior from commercial network utilities. Reference research must include its source and license.

## Project generation

`project.yml` is the source of truth for targets and build settings. After adding source files or changing target configuration, regenerate `EZgate.xcodeproj` and include the generated project change.

## Releasing (maintainers)

1. Bump `CFBundleShortVersionString` of both targets and `EZGATE_FILTER_BUILD` in `project.yml`, then run `xcodegen generate`. macOS only replaces an installed filter with a higher build, and the build number is also part of the XPC service name so an update works without a restart.
2. Archive the `EZgate` scheme in Release, export it with method `developer-id` and destination `upload` to notarize it, then run `xcodebuild -exportNotarizedApp`.
3. Check `spctl -a -vv -t exec EZgate.app` reports `Notarized Developer ID`, zip the app with `ditto -c -k --keepParent`, and attach it to a GitHub release with its SHA-256.

## Suggested commit style

Use small, working commits such as `feat: add traffic report bridge` or `test: cover profile fallback`. Do not intentionally commit a broken build.
