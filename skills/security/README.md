# Cluster security - Protection, Compliance, and Trust Boundaries

Skills in this cluster protect the system and its users: configuration surfaces,
dependencies, data privacy, API contracts, permissions, and security-relevant
code patterns. They share a common concern: **what could go wrong, who could be
harmed, and where is the trust boundary violated?**

These skills serve security-minded developers, ops engineers, and anyone preparing
for a compliance review. They complement - never replace - dedicated security
scanners; their value is in finding the structural and architectural issues those
scanners miss.

## Skills in this Cluster

| Skill | Trigger | Audience | Purpose |
|--|--|--|--|
| [config-cartographer](../security/config-cartographer/) | /config-map | Both | Map a system's full configuration surface: every env var, setting, flag - where it is defined versus where it is read. Reports read-but-never-defined (crash candidates), defined-but-never-read (orphans), and divergent defaults. **Never outputs values, only keys.** |
| [dep-inheritance](../security/dep-inheritance/) | /deps-audit | Senior | Every dependency: purpose, risk, replaceability, exit plan. Distinguishes deep transitive risk from direct declarations. |
| [api-contract-guardian](../security/api-contract-guardian/) | /api-diff | Senior | Detect breaking changes between two API states; generate migration notes and per-consumer impact analysis. |
| [authorization-xray](../security/authorization-xray/) | /authz | Senior | Reconstruct the permission matrix from code: who can do what, where unprotected endpoints live, where the model is inconsistent. |
| [data-trail-tracker](../security/data-trail-tracker/) | /data-trail-tracker | Senior > Vibe | Map PII fields and their sinks: where personal data flows (logs, third-party APIs, exports, error reports). |
| [input-validation-audit](../security/input-validation-audit/) | /input-audit | Senior > Vibe | Find every external input surface, classify its validation state (none/weak/adequate), and rank gaps by severity. |

## Cross-Links

- [quality/README.md](../quality/README.md) - `quality/cluster` lists the
  `security-smell-scanner` as a quality-relevant cross-link.
