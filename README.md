# AGENTS - Skill Program

**122 executable developer skills** for LLM-powered coding agents. Each skill is a
deterministic collector script (`scripts/*.ps1`) paired with an LLM instruction file
(`SKILL.md`) that together audit, analyze, and report on real codebases without
modifying them.

| | | | |
|--|--|--|--|
| ![skills](https://img.shields.io/badge/skills-122-2ea44f) | ![sprints](https://img.shields.io/badge/sprints-133-blue) | ![license](https://img.shields.io/badge/license-MIT-yellow) | ![status](https://img.shields.io/badge/status-active-brightgreen) |

---

## What Makes This Different

AGENTS skills are **not prompt templates**. Every skill has two halves:

1. **Collector** - a deterministic PowerShell script that extracts hard evidence
   from the target project (file content, git history, dependency trees, config files).
   Output: structured JSON.
2. **LLM judge** - the `SKILL.md` instructs the LLM to interpret the evidence,
   classify findings, and write a Markdown report with confidence levels.

This means: **every claim in every report is backed by a file:line reference.**
No hallucinations, no guesswork.

All skills are **read-only by default**. The `~/.claude/` directory is
off-limits - no skill ever modifies your agent configuration.

---

## Skills at a Glance

| Cluster | Skills | Focus | Sprints |
|--|--:|--|--:|
| [Quality](skills/quality/) | 21 | Code smells, patterns, refactoring signals | 41-50 |
| [Security](skills/security/) | 21 | Protection, compliance, trust boundaries | 51-64 |
| [Understanding](skills/understanding/) | 14 | Knowledge preservation, onboarding, architecture | 65-75 |
| [Data](skills/data/) | 14 | Schemas, migrations, test coverage | 76-87 |
| [Operations](skills/operations/) | 15 | Deployment, resilience, maintainability | 88-99 |
| [Runtime](skills/runtime/) | 14 | Performance, reproduction, production mirroring | 100-111 |
| [AI/ML](skills/ai-ml/) | 14 | LLM apps, ML pipelines | 39-40, 112-123 |
| [_meta](skills/_meta/) | 9 | Repository lifecycle tooling | 124-133 |
| **Total** | **122** | | **133 sprints** |

---

## Quick Start

```bash
# Clone the repo
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git

# Install a single skill (example: intent-archaeology)
cp -r skills/quality/intent-archaeology ~/.claude/skills/

# Invoke via your agent's trigger mechanism
# Your agent reads the SKILL.md and runs the collector script
```

No package manager. No dependencies. Each skill is self-contained in its
directory.

---

## Complete Skill Inventory

### Quality - 21 skills

| Trigger | Skill | What It Does |
|---|---|---|
| `/intent` | intent-archaeology | Recover original intent from tangled code |
| `/spec-check` | spec-lie-detector | Check if code matches its spec |
| `/blast` | side-effect-radar | Find untracked side effects |
| `/consist` | consistency-enforcer | Enforce naming and structure conventions |
| `/bury` | dead-code-burier | Find and remove dead code |
| `/doc-drift` | doc-drift-detector | Detect documentation that diverges from code |
| `/vocab` | vocabulary-guardian | Enforce domain vocabulary |
| `/perf` | performance-anti-pattern-detector | Find common performance anti-patterns |
| `/code-smell` | code-smell-detection | Detect code smells across languages |
| `/code-clone` | code-clone-detector | Find duplicated code blocks |
| `/error-audit` | error-handling-auditor | Audit error handling completeness |
| `/comment-lies` | comment-lie-detector | Find comments that contradict code |
| `/test-honesty` | test-honesty-auditor | Find tests that cannot fail |
| `/name-lies` | misleading-name-detector | Find misleading variable and function names |
| `/migration-limbo` | migration-limbo-detector | Find stuck migrations |
| `/clone-drift` | clone-drift-tracker | Track how cloned code diverges over time |
| `/magic-values` | magic-value-genealogist | Trace magic values to their origin |
| `/reinvented-wheels` | wheel-reinvention-detector | Find reimplemented standard library features |
| `/footguns` | api-footgun-reviewer | Find API usage patterns that cause bugs |
| `/paranoia` | paranoia-profiler | Find overly defensive code |
| `/invariants` | invariant-miner | Find implicit invariants that could break |

### Security - 21 skills

| Trigger | Skill | What It Does |
|---|---|---|
| `/deps-audit` | dep-inheritance | Audit dependency inheritance chains |
| `/config-map` | config-cartographer | Map configuration surface area |
| `/api-diff` | api-contract-guardian | Detect breaking API changes |
| `/authz` | authorization-xray | Map authorization boundaries |
| `/data-trail-tracker` | data-trail-tracker | Track data lineage through the system |
| `/security-scan` | security-smell-scanner | Find common security smell patterns |
| `/input-audit` | input-validation-audit | Audit input validation coverage |
| `/secret-lifecycle` | secret-lifecycle-auditor | Audit secret creation, rotation, and expiration |
| `/error-leakage` | error-message-leakage | Find sensitive data in error messages |
| `/permission-chain` | permission-chain | Map permission escalation paths |
| `/rate-shape` | rate-limit-shape-analyzer | Analyze rate limit configuration |
| `/third-party-trust` | third-party-trust | Audit third-party dependency trust |
| `/authz-coverage` | authz-coverage-gap-detector | Find endpoints without authorization |
| `/ssl-drift` | tls-config-drift | Detect TLS configuration drift |
| `/log-injection` | log-injection-detector | Find log injection vulnerabilities |
| `/bypass-detector` | type-confusion-bypass-detector | Find type confusion bypass patterns |
| `/flask-detector` | flask-anti-pattern-detector | Find Flask-specific security anti-patterns |
| `/crypto-downgrade` | crypto-downgrade-detector | Find cryptographic downgrade attacks |
| `/cors-drift` | cors-config-drift | Detect permissive or inconsistent CORS |
| `/session-anomaly` | session-state-anomaly | Find session management gaps |
| `/ssrf-detector` | ssrf-detector | Find server-side request forgery vectors |

### Understanding - 14 skills

| Trigger | Skill | What It Does |
|---|---|---|
| `/testament` | knowledge-testament | Extract hidden project knowledge |
| `/onboarding-pathfinder` | onboarding-pathfinder | Generate onboarding guide from codebase |
| `/arch-vis` | architecture-visualizer | Visualize component architecture |
| `/explain` | domain-narrator | Explain domain concepts from code |
| `/api-survey` | api-surface-documenter | Document all API endpoints |
| `/errors-overview` | error-handling-overview | Map all error handling patterns |
| `/conventions` | convention-extractor | Extract implicit coding conventions |
| `/test-strategy` | test-strategy-designer | Design test strategy from code analysis |
| `/config-docs` | config-surface-documenter | Document configuration surface |
| `/integrations` | integration-landscape | Map external integration points |
| `/tech-debt` | tech-debt-narrator | Narrate technical debt with evidence |
| `/dataflow` | data-flow-cartographer | Map data flow between components |
| `/runbook` | runbook-automator | Auto-generate runbooks |
| `/changelog` | changelog-narrator | Generate narrative changelogs |

### Data - 14 skills

| Trigger | Skill | What It Does |
|---|---|---|
| `/migrate` | migration-surgeon | Analyze and fix data migrations |
| `/testgap` | test-gap-cartographer | Find untested data access paths |
| `/schema-health` | schema-health-scanner | Assess database schema health |
| `/migration-safety` | migration-safety-inspector | Inspect migration safety |
| `/sql-smells` | sql-smell-detector | Find SQL anti-patterns |
| `/schema-docs` | schema-documentation-generator | Generate schema documentation |
| `/n-plus-one` | n-plus-one-hunter | Detect N+1 query patterns |
| `/data-contract` | data-contract-auditor | Audit data contract compliance |
| `/schema-drift` | schema-drift-tracker | Track schema drift over time |
| `/fixture-audit` | data-fixture-auditor | Audit test data fixtures |
| `/pii-scan` | pii-schema-classifier | Classify PII in database schemas |
| `/migration-test` | migration-test-writer | Auto-generate migration tests |
| `/infer-rels` | relationship-inference | Infer entity relationships |
| `/seed-data` | seed-data-strategist | Design seed data strategies |

### Operations - 15 skills

| Trigger | Skill | What It Does |
|---|---|---|
| `/timebomb` | timebomb-scanner | Find time bombs and deadlines in code |
| `/failsim` | failure-simulator | Simulate failure scenarios |
| `/dockerfile-audit` | dockerfile-best-practices | Audit Dockerfile best practices |
| `/runbook-audit` | runbook-auditor | Audit runbook completeness |
| `/rollback` | rollback-readiness | Assess rollback readiness |
| `/log-audit` | log-quality-auditor | Audit logging quality and coverage |
| `/deploy-freq` | deployment-frequency-tracker | Track deployment frequency |
| `/backup-scan` | backup-coverage-scanner | Scan backup coverage |
| `/leak-scan` | leak-detector | Detect resource leaks |
| `/healthcheck` | healthcheck-mapper | Map health check coverage |
| `/deploy-drift` | deployment-drift-detector | Detect deployment configuration drift |
| `/ci-debt` | ci-debt-analyzer | Analyze CI pipeline technical debt |
| `/capacity` | capacity-early-warning | Early warning for capacity issues |
| `/env-drift` | env-drift-tracker | Track environment configuration drift |
| `/dep-graveyard` | dependency-graveyard | Find dead dependencies |

### Runtime - 14 skills

| Trigger | Skill | What It Does |
|---|---|---|
| `/repro` | repro-builder | Build minimal reproduction cases |
| `/mirror` | prod-mirror | Mirror production configuration locally |
| `/startup` | startup-profile-analyzer | Analyze startup initialization chain |
| `/error-map` | error-propagation-mapper | Map error propagation paths |
| `/concurrency` | concurrency-hazard-scanner | Find concurrency hazards |
| `/cache-audit` | cache-effectiveness-auditor | Audit cache effectiveness |
| `/lifetime` | process-lifetime-tracker | Analyze graceful shutdown readiness |
| `/schema-query` | schema-query-mismatch | Find schema-query mismatches |
| `/sideorder` | side-effect-ordering | Analyze side-effect ordering risks |
| `/mock-gap` | mock-production-gap | Find mock-production divergences |
| `/type-mismatch` | runtime-type-mismatch | Find unvalidated runtime type assumptions |
| `/shutdown` | shutdown-gracefulness | Analyze shutdown hook implementation quality |
| `/runtime-deps` | dependency-runtime-availability | Find dynamic imports and resources that fail at runtime |
| `/dead-runtime` | dead-code-at-runtime | Find feature flags, date gates, and env checks that make code unreachable |

### AI/ML - 14 skills

| Trigger | Skill | What It Does |
|---|---|---|
| `/prompt-inspect` | prompt-injection-detector | Detect prompt injection vulnerabilities |
| `/llm-cost` | llm-cost-controller | Analyze and optimize LLM usage costs |
| `/prompt-quality` | prompt-quality-auditor | Audit prompt structure, specificity, and injection susceptibility |
| `/embed-quality` | embedding-quality-scanner | Scan embedding chunking strategy, model parity, and configuration |
| `/train-leak` | training-data-leakage-detector | Detect data leakage in ML training pipelines |
| `/guardrails` | model-output-guardrail-auditor | Audit model output consumption for safety gaps |
| `/prompt-drift` | prompt-drift-tracker | Track prompt changes across git history for semantic drift |
| `/token-budget` | token-budget-analyzer | Analyze static code for token usage waste and budget risks |
| `/rag-consistency` | rag-pipeline-consistency-auditor | Audit RAG pipeline config for consistency issues |
| `/llm-obs` | llm-call-observability-gap | Find LLM API calls lacking observability coverage |
| `/ai-log` | ai-decision-logger | Find model-based decision points missing audit logging |
| `/tool-fidelity` | tool-call-fidelity-checker | Check tool/function definitions for hallucination-prone schemas |
| `/finetune-deps` | fine-tune-dependency-check | Find fine-tuned model references with deprecated base models |
| `/ml-determinism` | ml-pipeline-determinism-check | Find sources of non-determinism in ML training pipelines |

### Meta - 9 skills

| Trigger | Skill | What It Does |
|---|---|---|
| `/project-init` | project-init | Initialize new AGENTS-compatible project structure |
| `/elevate` | elevate | Elevate skill quality to target standard |
| `/skill-dedup` | skill-dedup | Detect functional overlap between skills |
| `/manifest-audit` | manifest-audit | Verify disk vs tracking vs README consistency |
| `/smoke-coverage` | smoke-coverage | Audit smoke test coverage across all skills |
| `/cluster-purity` | cluster-purity | Detect cross-cluster boundary violations |
| `/trigger-audit` | trigger-audit | Validate trigger uniqueness and convention |
| `/benchmark` | benchmark | Benchmark collector script performance |
| `/skill-lifecycle` | skill-lifecycle | Report skill freshness and lifecycle status |

---

## Repository Structure

```
.
+-- README.md                    # This file
+-- LICENSE                      # MIT
+-- skills/                      # All skills, organized by cluster
    +-- quality/                 # 21 quality assurance skills
    +-- security/                # 21 security analysis skills
    +-- understanding/           # 14 code understanding skills
    +-- data/                    # 14 data management skills
    +-- operations/              # 15 operations and SRE skills
    +-- runtime/                 # 14 runtime analysis skills
    +-- ai-ml/                   # 14 AI/ML pipeline skills
    +-- _meta/                   # 9 meta-tooling skills
```

Each skill directory follows a consistent structure:

```
skills/<cluster>/<skill-name>/
+-- SKILL.md                     # LLM instruction file with trigger and workflow
+-- scripts/
    +-- <collector>.ps1          # Deterministic evidence collector (PowerShell)
```

---

## Architecture

```
+-------------------------------------------------------------------+
|                     LLM Agent (Sonnet, Opus, Haiku, ...)          |
|                                                                   |
|   SKILL.md triggers (/intent, /startup, ...)                      |
|      -> Step 1: Clarify target                                    |
|      -> Step 2: Run collector script                              |
|      -> Step 3: Classify findings from JSON evidence              |
|      -> Step 4: Write Markdown report with confidence levels      |
|      -> Step 5: Summarize results                                 |
+-------------------------------------------------------------------+
                            |
                            v
+-------------------------------------------------------------------+
|   Collector Script (PowerShell, deterministic)                    |
|                                                                   |
|   Input:  Project directory                                       |
|   Output: Structured JSON (file:line evidence)                    |
|   + console summary (=== TITLE ===)                               |
|                                                                   |
|   * No side effects on target project                             |
|   * UTF-8 output encoding                                         |
|   * ErrorActionPreference = 'Stop'                                |
|   * Tested against smoke fixtures                                 |
+-------------------------------------------------------------------+
```

## Principles

- **Evidence over opinion** - every report finding carries a `file:line` reference
  and a confidence level (`proven` | `likely` | `suspected`)
- **Collector + LLM split** - deterministic scripts gather facts; the LLM judges
  context and risk
- **Read-only by default** - skills analyze, they don't modify (exceptions require
  explicit user approval)
- **`~/.claude/` is protected** - no skill ever touches your agent configuration
- **Ship-ready** - every skill has a smoke test with fixture data and a verified
  JSON output contract

## License

[MIT](LICENSE)