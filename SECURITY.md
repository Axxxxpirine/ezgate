# Security policy

## Principles

- least privilege
- public Apple APIs only
- fail open when the development rule snapshot is unavailable
- no kernel extensions
- no SIP/Gatekeeper bypasses
- no arbitrary shell execution from the UI
- no unauthenticated local network endpoint
- no downloaded executable rules
- no packet-content persistence

The Content Filter runs in user space as a System Extension. Its data provider receives only the code needed to identify a flow and make a deterministic rule decision. The shared rules file is atomic and versioned.

## Sensitive material

Certificates, private keys, provisioning profiles, Team-specific secrets, tokens, `.env` files, and notarization credentials must never be committed. `.gitignore` excludes common signing artifacts, but contributors remain responsible for reviewing staged changes.

## Reporting a vulnerability

Until a public security address exists, open a minimal GitHub security advisory after the repository is published. Do not include personal traffic metadata, packet captures, credentials, or exploitable details in a public issue.

Reports should identify the affected commit/version, macOS version, reproduction prerequisites, impact, and a safe proof of concept. Maintainers should acknowledge reports promptly and coordinate disclosure after a fix is available.

## Supported versions

During pre-release development only the current main branch is supported. This file will list supported releases after the first signed distribution.

