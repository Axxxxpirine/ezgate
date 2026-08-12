# License decision

## Decision: MIT

MIT is selected for the initial EZgate codebase. It is short, permissive, familiar to macOS/Swift contributors, and allows broad personal and commercial reuse with attribution and warranty disclaimer.

## MIT compared with GPL-3.0

| Topic | MIT | GPL-3.0 |
| --- | --- | --- |
| Commercial reuse | Allowed | Allowed |
| Proprietary forks | Allowed | Distributed derivatives must remain GPL-compatible and provide source |
| Contribution barrier | Low | Some companies avoid strong copyleft dependencies |
| Protection of downstream openness | Weak | Strong |
| License complexity | Low | Higher, especially around combined works/distribution |

The tradeoff is deliberate: MIT cannot prevent a proprietary fork. Project identity/trademarks and community governance can be handled separately if needed.

## Third-party code

No GPL code may be copied into this MIT codebase. LuLu can be studied as an open-source technical reference only after checking the license and the exact provenance of an idea. No code, assets, design, wording, or behavior may be copied from TripMode, Little Snitch, or another proprietary product.

Any dependency proposal must document its license, necessity, maintenance health, and binary/distribution implications before adoption.

