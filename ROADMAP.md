# Roadmap

## Completed foundation

- native menu bar and Settings scenes
- real `NEFilterReport` traffic provider with no simulated fallback
- app list, RX/TX, rates, search, sorting, and icons/fallback
- per-profile Allow/Block and default policy
- Normal, Hotspot, and Restrictive profiles
- pause filtering
- atomic profile/rule persistence
- SQLite Session/Today storage primitives
- NWPath network-context monitor
- automatic profile application from configured network signatures
- Content Filter system-extension target and audit-token signing resolver
- signed system-extension activation and first-run onboarding
- XPC bridge between app and filter, restricted to the signed EZgate app
- immediate blocking of already-open connections after a rule change
- Network Statistics window with periods, chart, and per-app breakdown
- reset of history and live counters
- Developer ID signed, notarized release
- filter updates without a restart (XPC service name versioned per filter build)
- core unit test suite and required project documentation

## Next: public release

- persist rules inside the extension so filtering survives a restart before the app launches
- explicit deactivation, denied, and recovery states in the UI
- resolve app names, executable URLs, icons, PIDs, and helper groups on the appropriate side
- final app/menu-bar icon and screenshots

## Next: complete MVP

- permission-aware SSID mapping UI
- robust today/session rollups and cleanup/retention
- UI automation for menu search, rule toggle, profile change, and Settings
- String Catalog with English source strings and French/German/Italian readiness
- performance validation at 100 processes and 1,000 flows

## Later

- temporary blocks and “until app closes/network changes”
- quotas and local notifications
- JSON/CSV export
- domain/DNS history where public APIs and privacy constraints permit
- application groups and profile import/export
- Shortcuts, CLI, widgets, and advanced charts
- bandwidth limits only if a separate public-API feasibility study finds a legitimate low-overhead design
