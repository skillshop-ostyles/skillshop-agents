---
name: clone-drift-tracker
description: "Clone drift tracker: detects code blocks that USED to be clones (identical at past git ref) and have since drifted apart. Mines git history to compare function-body hashes between HEAD and HEAD~N (default 100), and reports pairs whose semantics diverged on one side but not the other. Read-only. Audience: Senior. Trigger: /clone-drift"
trigger: /clone-drift
---

## What this is for

The dangerous clones are not the identical ones - they are the ones that USED
to be identical and silently diverged. One got a bugfix, the twin did not.
This skill mines git history for code blocks that were once byte-identical at
a past ref and now have different body hashes.

The static-only `code-clone-detector` cannot see drift through time. Mutation
testing (Stryker, PIT) tests fail-ability dynamically but needs the full
test run. This is the zero-runtime, deterministic temporal complement.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided, the path exists, AND it is a git repo.
3. Run: `scripts/drift-scan.ps1 -ProjectDir "<path>" [-PastRef "v1.4"]`
   - If not given, defaults to `HEAD~100` (compare against 100 commits ago).
4. LLM reads the JSON output. For each drift pair:
   - Read the `currentSnippet` and `pastSnippet`.
   - What changed on the current side?
   - Did the other side get the same fix? (Often the answer is no.)
   - Is one side's change a missed migration, a missing bugfix, or an
     intentional specialization?
5. Classify: `missed-fix` (high) / `intentional-divergence` (informational).
6. Confidence: `proven` (clear functional gap), `likely` (likely gap),
   `suspected` (judgment call).
7. Write `clone-drift-report.md` to the working directory.

## Usage

```
/clone-drift                            # interactive
/clone-drift <dir>                      # against HEAD~100
/clone-drift <dir> -PastRef "v1.4.0"    # specific ref
/clone-drift -help                      # show usage
```

Returns JSON with `pairs[]`:
`{functionName, currentFile, pastFile, currentHash, pastHash, pastRef,
pastSnippet, currentSnippet}` plus summary.
