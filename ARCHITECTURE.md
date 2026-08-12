# Architecture

## Goals

EZgate separates user interface, policy, persistence, traffic sources, and privileged filtering. The rule engine is deterministic and testable without SwiftUI, NetworkExtension, entitlements, or an active network.

## Targets

```text
EZgate.app
├── SwiftUI MenuBarExtra and Settings
├── AppModel (main-actor presentation state)
├── MockTrafficProvider / future RealTrafficProvider
└── EZgateCore.framework
    ├── models
    ├── RuleEngine and NetworkContextMatcher
    ├── TrafficAggregator
    ├── ProfileStore (atomic JSON)
    └── StatisticsStore (SQLite actor)

EZgateNetworkExtension.systemextension
├── FilterDataProvider
├── audit-token → signing-identifier resolver
├── read-only shared rule snapshot
└── EZgateCore.framework
```

## Data flow

The app updates a `NetworkProfile`, persists it atomically, and publishes a versioned `SharedRuleSnapshot` to the App Group. The Content Filter reads that snapshot and calls the pure `RuleEngine` for every new flow. Missing/corrupt configuration fails open so a development defect cannot silently disconnect the Mac.

The signed real-data architecture extends the macOS data provider's `handle(_:)` report path. It receives `NEFilterReport` metadata and byte counters, aggregates events before storage/UI updates, and publishes compact snapshots through the shared App Group. The provider must never create a local HTTP server or write packet contents; cross-process exchange remains narrow, versioned, and local.

## Concurrency

- `AppModel` and observable UI services are `@MainActor`.
- Traffic providers expose `AsyncStream<[AppTraffic]>` and update at a bounded cadence.
- `ProfileStore` and `StatisticsStore` are actors.
- SQLite uses one actor-confined full-mutex connection.
- UI receives application-level aggregates, never per-packet updates.

## Rule precedence

1. Paused filtering returns Allow.
2. An explicit per-profile application rule wins.
3. The active profile default policy applies to unknown/new apps.

This directly supports a Hotspot profile with `defaultPolicy = block` and a short allowlist.

## Identity and grouping

The canonical key preference is bundle identifier, signing identifier, executable URL, then display name. On macOS filter flows are resolved from audit tokens through Security.framework. Helpers can be grouped into one `AppIdentity` while retaining process IDs/names for advanced views.

## IPC decision

App Group files were chosen for immutable rules and compact report snapshots because Apple supports sharing data between related macOS targets through an App Group. Files are local, auditable, low latency, and require no listening socket. XPC is reserved only if later measurement shows a need. No local HTTP endpoint is permitted.

## Storage

- profiles/rules/preferences: small atomic Codable JSON document
- extension rules: versioned atomic JSON snapshot in App Group
- traffic history: SQLite with indexes on date and session

SwiftData was not selected because the schema is simple, SQL aggregation is explicit, and cross-process/restricted-extension boundaries benefit from stable files rather than an app-only model container.

## Performance

Mock and real providers publish at approximately 1 Hz. Network Extension statistics use the system report cadence instead of payload peeking. Lists use stable application IDs and `LazyVStack`. Aggregation occurs before observable state changes. This design targets 100 processes and 1,000 active flows without one SwiftUI mutation per flow or packet.

## Error states

The UI model can surface monitoring unavailable, persistence/statistics errors, and development mode. Signed onboarding must add explicit inactive, awaiting approval, denied, and active states before real mode becomes the default.

## Bundle identifiers

Bundle identifiers are centralized in `project.yml` and entitlement/configuration files. Changing `ch.ezgate.app` requires updating the app, system extension, App Group, Apple portal identifiers, provisioning profiles, and documentation as one atomic change.
