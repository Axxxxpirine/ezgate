# Technical feasibility

Verified against Apple documentation and the macOS 26.5 SDK on 12 August 2026. Apple documentation is the primary reference.

## Executive decision

EZgate should use a Network Extension Content Filter packaged as a macOS System Extension. `NEFilterDataProvider` is the public API that can make per-flow allow/drop decisions without a legacy kernel extension. `NWPathMonitor` supplies network-context changes. An App Group carries immutable rule snapshots from the app to the data provider. SQLite stores statistics in the app/control side.

The mock MVP can build and run without signing. Real filtering cannot be truthfully enabled without an Apple Developer team, matching provisioning profiles, system-extension activation, filter configuration, and explicit user approval.

## 1. Which macOS API filters connections by application?

`NEFilterDataProvider` receives an `NEFilterFlow` for each filtered socket/WebKit flow and returns `NEFilterNewFlowVerdict.allow()` or `.drop()`. Apple describes Content Filter providers as appropriate for personal firewalls and states that providers cannot modify traffic, only allow or drop it. On macOS, TN3134 requires a Content Filter provider to be packaged as a System Extension (macOS 10.15+).

Selected: `NEFilterDataProvider`. Rejected as the primary design: a packet tunnel, transparent proxy, legacy KEXT, undocumented socket inspection, or Packet Filter hooks.

## 2. Can EZgate recover the originating application identity?

Yes, with a macOS-specific caveat. `NEFilterFlow.sourceAppIdentifier` is unavailable on macOS in the current SDK even though it exists on iOS. macOS exposes `sourceAppAuditToken` and `sourceProcessAuditToken`. The process token can differ when a system process creates a connection on behalf of an app.

The implemented resolver passes the app audit token to Security.framework (`SecCodeCopyGuestWithAttributes`, then signing information) and uses the signing identifier as the stable rule key. A later `ProcessResolver` stage on the less restricted side will enrich it with PID, executable URL, bundle metadata, icon, and helper-process grouping. Unknown/unresolvable apps remain explicitly “Unknown application”; identity is never invented.

## 3. Can EZgate obtain RX/TX per flow?

Yes. `NEFilterReport.bytesInboundCount` and `bytesOutboundCount` expose byte counts. The closed-flow report contains final counts. A verdict can request statistics reports using `statisticsReportFrequency`; `.medium` is documented as approximately once per second, matching the UI target.

This is preferable to peeking at all payload bytes. Peeking would increase overhead and expose content unnecessarily. The production report bridge still needs to be completed; the current app therefore does not claim real RX/TX and displays `Mock Network Data`.

## 4. Can data be aggregated by bundle identifier?

Yes, once the signing/audit identity is resolved. `TrafficAggregator` already combines multiple process samples into one `AppIdentity`. The grouping key preference is bundle identifier, then signing identifier, then executable path, then display name. Explicit group mappings (for example Chrome or Adobe helper families) can be added without changing the rule engine.

## 5. Which entitlements are required?

Development/App Store signing:

- app and provider: `com.apple.developer.networking.networkextension = [content-filter-provider]`
- containing app: `com.apple.developer.system-extension.install = true`
- app and relevant providers: a matching `com.apple.security.application-groups` value
- App Sandbox as appropriate to each target

Direct Developer ID distribution uses `content-filter-provider-systemextension` instead of `content-filter-provider`. The App ID capability and provisioning profiles must contain the same authorized values. Values in `Config/` are templates; Team ID/App Group values must be changed together and regenerated in the Apple developer portal.

## 6. Is an Apple Developer account required?

Yes for a functioning Content Filter build. Unsigned/free-team work can compile domain logic and the mock UI, but installing and running the privileged Network Extension requires the Apple Developer Program, registered identifiers/capabilities, signing identities, and profiles.

## 7. Can a Network Extension be distributed outside the Mac App Store?

Yes. TN3134 states that a macOS Content Filter packaged as a System Extension supports direct Developer ID distribution. The provider must not be packaged as the App Store-only app-extension variant.

## 8. What are the Developer ID constraints?

- Developer ID-specific `-systemextension` entitlement value
- Developer ID provisioning profiles for both containing app and provider
- same Team ID unless the special redistributable entitlement is granted
- hardened runtime and inside-out code signing
- notarization and stapling for normal Gatekeeper distribution
- user approval of the system extension/content filter
- no assumption that Xcode automatically fixes mismatched exported entitlements

No certificate, profile, secret, or Team ID is committed.

## 9. How does local development differ from distribution?

Local unsigned build: compiles all targets and runs the mock UI; cannot install the filter.

Development-signed build: uses `content-filter-provider`, a development profile, and user/system approval; `get-task-allow` may affect testing behavior. It must not be treated as representative of Developer ID packaging.

Direct distribution: uses Developer ID certificates/profiles, `content-filter-provider-systemextension`, hardened runtime, notarization, and the same Team/App Group relationships across nested code.

App Store distribution: uses App Store profiles and the standard entitlement value, subject to App Review and the applicable Network Extension capability approval.

## 10. What is impossible or unreliable with public APIs alone?

- A Content Filter cannot generally shape bandwidth; it permits or drops traffic. `limitBandwidth` remains a model/roadmap concept, not a promise.
- It cannot modify packet payloads.
- A precise iPhone hotspot label is not guaranteed. `NWPath.isExpensive` is a useful signal, not proof of a specific hotspot. SSID access is privacy-gated and may be unavailable.
- Bundle/display identity may be unavailable for some system/delegated flows; audit tokens must be handled conservatively.
- Existing established connections may not instantly reflect a changed new-flow policy unless the provider updates or terminates those flows using supported APIs.
- Full URLs inside encrypted traffic are not generally visible to a traditional Content Filter. macOS 26 URL Filter is a separate API and not required for this MVP.
- Content/payload logging is both unnecessary for EZgate and restricted by the data-provider sandbox.

## Network context

`NWPathMonitor` reports path status, interface types, preferred interface name, expensive/constrained flags, and route changes. EZgate uses these values as explicit matching signatures. SSID mapping will be optional and permission-aware; no SSID or hotspot identity is fabricated.

## Persistence decision

SQLite was selected for traffic samples because it is transactional, handles indexed time/session queries, avoids loading history into memory, and ships with macOS. SwiftData is convenient for app-only object graphs but introduces model/container coupling and is awkward across the restricted extension boundary. Atomic Codable JSON is intentionally used for the small profile/rule configuration and read-only shared snapshots.

## Minimum OS decision

macOS 14 is the minimum. It supports Swift Observation, modern SwiftUI menu-bar scenes, `SMAppService`, Network.framework, and the required system-extension APIs while avoiding unnecessary compatibility branches. The Network Extension itself could target older systems, but doing so would complicate the app without improving the Apple Silicon-first MVP.

## References

- Apple, [Content filter providers](https://developer.apple.com/documentation/networkextension/content-filter-providers)
- Apple, [NEFilterDataProvider](https://developer.apple.com/documentation/networkextension/nefilterdataprovider)
- Apple, [NEFilterFlow](https://developer.apple.com/documentation/networkextension/nefilterflow)
- Apple, [sourceAppAuditToken](https://developer.apple.com/documentation/networkextension/nefilterflow/sourceappaudittoken)
- Apple, [sourceProcessAuditToken](https://developer.apple.com/documentation/networkextension/nefilterflow/sourceprocessaudittoken)
- Apple, [NEFilterReport bytesInboundCount](https://developer.apple.com/documentation/networkextension/nefilterreport/bytesinboundcount)
- Apple, [statisticsReportFrequency](https://developer.apple.com/documentation/networkextension/nefilterdataverdict/statisticsreportfrequency)
- Apple, [NEFilterReport.Frequency](https://developer.apple.com/documentation/networkextension/nefilterreport/frequency)
- Apple, [Network Extensions entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.networkextension)
- Apple, [TN3134: Network Extension provider deployment](https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment)
- Apple, [System Extensions](https://developer.apple.com/system-extensions/)
- Apple, [NWPath](https://developer.apple.com/documentation/network/nwpath)
- Apple, [Filtering Network Traffic sample](https://developer.apple.com/documentation/networkextension/filtering-network-traffic)
- Apple, [WWDC25: Filter and tunnel network traffic with NetworkExtension](https://developer.apple.com/videos/play/wwdc2025/234/)

