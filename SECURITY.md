# Security policy

## Principles

- least privilege
- public Apple APIs only
- fail open until the app has sent a rule snapshot
- no kernel extensions
- no SIP/Gatekeeper bypasses
- no arbitrary shell execution from the UI
- no network listener; the only local endpoint is an XPC service that accepts the EZgate app signed by the same Apple team
- no downloaded executable rules
- no packet-content persistence

The Content Filter runs in user space as a System Extension. Its data provider receives only the code needed to identify a flow and make a deterministic rule decision. Rule snapshots are versioned, and malformed ones are rejected. Every XPC connection to the filter must satisfy a code-signing requirement pinning the `ch.ezgate.app` identifier and the filter's own Team ID; unsigned or foreign processes cannot change rules, read traffic, or reset counters.

## Sensitive material

Certificates, private keys, provisioning profiles, Team-specific secrets, tokens, `.env` files, and notarization credentials must never be committed. Team IDs belong in the ignored `Config/Local.xcconfig`. `.gitignore` excludes common signing artifacts, but contributors remain responsible for reviewing staged changes.

## Reporting a vulnerability

Report vulnerabilities privately through GitHub: **Security → Report a vulnerability** on this repository. Do not include personal traffic metadata, packet captures, credentials, or exploitable details in a public issue.

Reports should identify the affected commit/version, macOS version, reproduction prerequisites, impact, and a safe proof of concept. Maintainers should acknowledge reports promptly and coordinate disclosure after a fix is available.

## Supported versions

During pre-release development only the current main branch is supported. This file will list supported releases after the first signed distribution.

