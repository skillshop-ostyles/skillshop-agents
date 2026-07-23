---
name: permission-chain
description: "Permission chain analyzer: extracts role definitions, role check sites, middleware mounts, and mutating routes. Identifies transitive chains (role A can reach endpoint E via routes R1,R2...), surfaces unprotected mutating routes (file-local check missing), detects divergent role-naming (same role defined differently in 3 files). Read-only. Audience: Senior. Trigger: /permission-chain"
trigger: /permission-chain
---

## What this is for

`if(user.role=='admin')` at one site is not the problem. Five such checks
across 3 roles plus middleware inheritance is the problem - who can do
WHAT, transitively. `authorization-xray` builds the permission matrix per
route. Missing: transitive closure, divergent-set detection, and unprotected
mutating routes where the only protection is middleware inheritance.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/permission-graph.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each finding:
   - **Unprotected mutating route** (no check within +/-40 lines): does it
     inherit from middleware? what is the abuse path if middleware fails?
   - **Divergent role set**: 4 files define `admin` differently. Is one
     the intended truth? Where is the mismatch?
   - **Diamond chains**: same role reaches endpoint via two paths with
     different truth-values.
   - **Broken chain** (set-without-verify): role gets set in middleware but
     no check ever compares against it.
5. Write `permission-chain-report.md` to the working directory.

## Usage

```
/permission-chain                           # interactive
/permission-chain <dir>                     # scan project
/permission-chain -help                     # show usage
```

Returns JSON with `roleDefines[]`, `roleChecks[]`, `middleware[]`,
`mutatingRoutes[]`, `unprotectedRoutes[]`, `knownRoles[]` plus summary counts.
