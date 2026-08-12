# Roadmap

## Completed foundation

- native menu bar and Settings scenes
- mock traffic provider with progressive values
- app list, RX/TX, rates, search, sorting, and icons/fallback
- per-profile Allow/Block and default policy
- Normal, Hotspot, and Restrictive profiles
- pause filtering
- atomic profile/rule persistence
- SQLite Session/Today storage primitives
- NWPath network-context monitor
- Content Filter system-extension target and audit-token signing resolver
- core unit test suite and required project documentation

## Next: signed real-network milestone

- add system-extension activation coordinator and explicit onboarding states
- configure `NEFilterManager` with user-visible error handling
- add the control/report provider required for `NEFilterReport`
- aggregate report byte counters by signing/bundle identifier
- publish compact App Group report snapshots
- add `RealTrafficProvider` and retain one-click mock selection for development
- test allow/drop against new and established TCP/UDP flows on a signed development machine
- resolve app names, executable URLs, icons, PIDs, and helper groups on the appropriate side

## Next: complete MVP

- automatic profile application from configured network signatures
- permission-aware SSID mapping UI
- robust today/session rollups and cleanup/retention
- signed onboarding, deactivation, and recovery paths
- UI automation for menu search, rule toggle, profile change, and Settings
- String Catalog with English source strings and French/German/Italian readiness
- performance validation at 100 processes and 1,000 flows
- final app/menu-bar icon and screenshots

## Later

- temporary blocks and “until app closes/network changes”
- quotas and local notifications
- JSON/CSV export
- domain/DNS history where public APIs and privacy constraints permit
- application groups and profile import/export
- Shortcuts, CLI, widgets, and advanced charts
- bandwidth limits only if a separate public-API feasibility study finds a legitimate low-overhead design

