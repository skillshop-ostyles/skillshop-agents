---
name: deployment-drift-detector
description: "Deployment drift detector: extracted deployed config (kubectl, terraform show, docker inspect) vs source-of-truth manifests, then LLM judges each drift's criticality in business context. Read-only. Trigger: /deploy-drift"
trigger: /deploy-drift
---
# /deploy-drift

Infrastructure declared in code vs infrastructure actually running: compare and classify each drift by criticality.

## What this is for

- Kubernetes manifests say 3 replicas but production has 1
- Terraform declares encrypted storage but the bucket is public
- Dockerfile pinnings differ between CI and deployed state
- **Read-only skill.** No automatic reconciliation, no infrastructure mutation.

## What You Must Do When Invoked

If `/deploy-drift -help` or `/deploy-drift -h` (without further arguments)
is invoked: output the `## Usage` section unchanged and stop.

Otherwise follow these steps in order, skipping none.

### Step 1 - Clarify target

Clarify `-ProjectDir`. Get confirmation.

### Step 2 - Scan

```powershell
& "<SKILL_DIR>/scripts/deploy-drift-scan.ps1" -ProjectDir "<path>"
```

### Step 3 - Classification

Read each drift in context:

- **Critical**: data loss, security exposure, availability impact (e.g. public S3 with PII, missing replica on payment API)
- **Major**: degradation, performance impact (e.g. resource limits removed, missing readiness probe)
- **Minor**: cosmetic, non-functional (e.g. label mismatch, different image tag in dev)
- **Info**: intentional drift (hotfix, scaling event, known deviation documented)

### Step 4 - Write report

File `deploy-drift-report.md` in current working directory:

1. **Summary** - counts per severity, total drifts.
2. **Drift table** - sorted critical first. Per drift: resource, field, declared, deployed, severity, remediation.
3. **False positives** in appendix (intentional drifts with evidence).
4. **Open questions**.

### Step 5 - Summarize

State report path, highlight critical drifts.

## Usage

```
/deploy-drift               # interactive
/deploy-drift <dir>         # scan project
/deploy-drift -help
```
