# Code Clone Detector - /code-clone

**Cluster:** `quality/` - **Audience:** Both (Senior + Vibe) - **Trigger:** `/code-clone`

## Purpose

Systematically finds duplicated code across all 4 clone types: exact copies (Type 1),
parameterized copies (Type 2), near-miss clones (Type 3), and semantic clones (Type 4).
Each cluster includes similarity scores, risk assessment, and a deduplication proposal.

## Detection Approach

The collector extracts all function/method/class blocks from source files:

- **Type 1:** SHA-256 hash of whitespace-normalized content; blocks with identical
  hashes are exact clones.
- **Type 2:** SHA-256 hash of token-normalized content (identifiers replaced with
  `<id>`, literals with `<lit>`); same structure = same hash.
- **Type 3:** Within each Type 2 group, pairwise token Jaccard similarity between
  original blocks; >= 0.7 similarity = near-miss clone.
- **Type 4:** File-level function-name vector similarity generates candidate pairs;
  LLM reads both files and determines if a semantic clone exists.

## Validation

LLM reads each clone cluster with full code context and answers:
- Is this a genuine clone or coincidental similarity?
- What is the risk tier (critical/medium/low)?
- What deduplication strategy applies (extract, merge, or leave as-is)?

## Reporting

Output is `clone-report.md` with executive summary, risk-tiered findings grouped
by clone type, false-positive section, and open questions.

## Files

```
scripts/clone-scan.ps1        # collector (4 clone types)
SKILL.md                      # skill definition
README.md                     # this file
```
