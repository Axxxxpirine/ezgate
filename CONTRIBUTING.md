# Contributing

EZgate welcomes focused contributions that preserve native macOS behavior, low resource use, transparency, and privacy.

## Setup

1. Install Xcode and XcodeGen.
2. Run `xcodegen generate`.
3. Build the `EZgate` scheme with signing disabled for mock development.
4. Run the unit tests before submitting changes.

## Design rules

- Keep `RuleEngine` and models independent of SwiftUI and NetworkExtension.
- Prefer async/await, actors, protocols, and dependency injection.
- Avoid global mutable state, force unwraps, force tries, aggressive polling, and per-packet UI mutations.
- Treat mock and real data as separate sources; never present mock data as captured traffic.
- Use OSLog without packet content, secrets, tokens, or unnecessary URLs.
- Add tests for rule precedence, grouping, persistence, and migrations.
- Use only public Apple APIs. Never require disabling SIP or Gatekeeper.

## Licensing and originality

Contributions are made under MIT. Do not paste GPL-incompatible code into the repository. Do not copy proprietary code, resources, UI, text, or distinctive behavior from commercial network utilities. Reference research must include its source and license.

## Project generation

`project.yml` is the source of truth for targets and build settings. After adding source files or changing target configuration, regenerate `EZgate.xcodeproj` and include the generated project change.

## Suggested commit style

Use small, working commits such as `feat: add traffic report bridge` or `test: cover profile fallback`. Do not intentionally commit a broken build.

