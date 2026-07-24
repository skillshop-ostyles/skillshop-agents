# Relationship Inference - /infer-rels

## What this is for

Most production databases have missing FK constraints - dropped for performance,
never declared in the first place, or only implied by naming conventions
(order.customer_id -> customer.id). This skill infers relationships from naming
patterns + query join patterns + ORM relation declarations, then the LLM
validates each inference against business logic.

The dominant failure mode is the implicit relationship that nobody documented,
leading to orphaned data, broken queries, and confused developers.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/relation-scan.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each candidate:
   - Read the `evidence` (naming, join, orm) and `confidence` score.
   - Is this a real business relationship? What is its cardinality?
   - Is there a reason it was not declared as FK (performance, cross-schema, legacy)?
   - Should it be promoted to a declared FK?
5. Confidence: `proven` (declared FK), `likely` (naming + join evidence),
   `suspected` (naming only).
6. Write `relationship-report.md` to the working directory.

## Usage

```
/infer-rels                         # interactive, prompts for directory
/infer-rels <dir>                   # scan project directory
/infer-rels -help                   # show usage
```

Returns JSON with `declaredFKs[]` and `inferredCandidates[]`: each candidate
entry `{fromCol, fromTable, toCol, toTable, evidence, confidence}`.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/data/relationship-inference ~/.claude/skills/
```

## Audience

Senior - data architects and engineers who need to understand and document
implicit relationships in their schema.
