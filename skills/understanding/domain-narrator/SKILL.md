---
name: domain-narrator
description: "Domain narrator: reads all public symbols in a codebase, clusters them by call-graph density into business domains, and writes plain-English descriptions of what each domain does. Collector extracts public symbols and call graphs; LLM per cluster produces domain name, business responsibility (1-2 sentences), and business rules extracted from code. Read-only. Audience: Both. Trigger: /explain"
trigger: /explain
---

## What this is for

Everyone can say what a module technically does — but what is its *business* responsibility? This skill extracts every public symbol, builds a call graph, clusters modules by dependency density into business domains, and produces a plain-English domain narrative describing each cluster's purpose, responsibilities, and extracted business rules.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/domain-map.ps1 -ProjectDir "<path>"`
4. Read the JSON output. For each cluster in `result.clusters[]`:
   - **Domain name:** What business concept does this cluster represent?
   - **Business responsibility:** 1-2 sentences explaining what this domain does in business terms.
   - **Business rules:** Extract business rules from the code (e.g., "orders cannot be cancelled after payment", "auth tokens expire in 1h").
   - **Module dependency graph:** For each module in the cluster, note which other clusters it depends on (interClusterCalls > 0).
5. Write `domain-narrative.md` to the working directory with one section per cluster.

## Usage

```
/explain                           # interactive
/explain <dir>                     # scan project
/explain -help                     # show usage
```

Returns JSON with `modules[]`, `clusters[]`, `callGraph{edges[], density}` plus summary counts.
