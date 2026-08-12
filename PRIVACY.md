# Privacy

EZgate is local-first and privacy-first. It has no account, cloud backend, telemetry, analytics, advertising SDK, or remote rule service. No EZgate user data leaves the Mac.

## Metadata observed

When the signed Network Extension is active, EZgate needs flow metadata such as the source app/process audit token, signing or bundle identifier, flow lifecycle, direction, network context, and byte counters. This metadata exists only to identify the responsible application, apply the selected rule, and calculate usage.

EZgate does not need or persist packet payloads, messages, authentication tokens, or complete URLs. It has no synthetic traffic source: an inactive Network Extension produces no application rows or traffic totals.

## Data stored

- profile names and default policies
- per-profile application Allow/Block rules
- last active profile and paused state
- application/signing identifiers and display names
- timestamps and local session identifiers
- active profile and network interface type
- received/sent byte totals

## Location

Configuration and statistics are stored in the user’s Application Support container. A signed build also uses the EZgate App Group container for the rule snapshot shared with the system extension.

## Retention

MVP statistics remain until the user deletes them in Settings or removes EZgate’s local data. A configurable retention policy is planned before long-term history is enabled by default.

## Deletion

Settings → Statistics → Delete All Statistics removes database rows. Removing the Application Support `EZgate` directory deletes configuration and statistics. A future signed uninstaller must also deactivate the system extension and remove the App Group data using supported macOS APIs.

## Logging

OSLog categories contain lifecycle and error metadata. EZgate avoids packet contents, tokens, secrets, and full URLs. Identifiers should use privacy annotations unless needed to diagnose a user-requested issue.

Any future telemetry would require an explicit project decision, documentation update, opt-in design, and code review. It must never be introduced silently.
