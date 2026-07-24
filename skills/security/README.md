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
| [secret-lifecycle-auditor](../security/secret-lifecycle-auditor/) | /secret-lifecycle | Senior | Inventory secret references, derive age from git, classify lifecycle health, recommend rotation. |
| [error-message-leakage](../security/error-message-leakage/) | /error-leakage | Both | Harvest error-return and log-error calls; classify leaked info type (stacktrace, SQL, env-vars). |
| [permission-chain](../security/permission-chain/) | /permission-chain | Senior | Reconstruct transitive role closure: which roles can reach which endpoints through middleware inheritance. |
| [rate-limit-shape-analyzer](../security/rate-limit-shape-analyzer/) | /rate-shape | Senior | Map rate-limit policies per endpoint; find missing or asymmetric limits on expansive operations. |
| [third-party-trust](../security/third-party-trust/) | /third-party-trust | Senior | Fingerprint every outbound call; classify trust contracts, SSRF risk, webhook verification gaps. |
| [authz-coverage-gap-detector](../security/authz-coverage-gap-detector/) | /authz-coverage | Senior | Detect mutating endpoints relying solely on middleware inheritance; find unprotected gaps. |
| [type-confusion-bypass-detector](../security/type-confusion-bypass-detector/) | /bypass-detector | Senior | Trace validation paths from input source to sink; test edge-case input shapes (str/int/obj/null/array) for bypass. |
| [tls-config-drift](../security/tls-config-drift/) | /ssl-drift | Senior | Find TLS version drifts, weak cipher suites, cert-pinning gaps, mTLS config issues, and FIPS mode inconsistencies. |
| [log-injection-detector](../security/log-injection-detector/) | /log-injection | Senior | Detect CRLF injection risks, unsanitized user input in log calls, and sensitive data exposure in log statements. |
| [flask-anti-pattern-detector](../security/flask-anti-pattern-detector/) | /flask-detector | Senior | Find Flask-specific security anti-patterns: hardcoded SECRET_KEY, debug mode in production, SSTI via render_template_string, pickle/eval on request data. |
| [crypto-downgrade-detector](../security/crypto-downgrade-detector/) | /crypto-downgrade | Senior | Find deprecated crypto algorithms, weak hash/encryption configs, hardcoded JWT secrets, and downgrade-vulnerable defaults. |
| [cors-config-drift](../security/cors-config-drift/) | /cors-drift | Senior | Map all per-route CORS policies; flag dangerous patterns (credentials+wildcard, reflecting origins, route-level drifts). |
| [session-state-anomaly](../security/session-state-anomaly/) | /session-anomaly | Senior | Detect session state machine violations: missing regeneration after login, missing cleanup on logout, no refresh token rotation. |
| [ssrf-detector](../security/ssrf-detector/) | /ssrf-detector | Senior | Find outbound HTTP calls with user-controlled URLs; classify validation coverage (hostname allowlist, scheme check, metadata-IP blocking). |

## Cross-Links

- [quality/README.md](../quality/README.md) - lists the
  `security-smell-scanner` as a quality-relevant cross-link.
