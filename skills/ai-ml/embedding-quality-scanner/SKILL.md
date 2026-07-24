---
name: embedding-quality-scanner
description: "Embedding quality scanner: audit chunking strategy, model selection, and embedding configuration. Read-only. Trigger: /embed-quality"
trigger: /embed-quality
---
# /embed-quality

RAG and semantic search depend on embedding quality. This skill finds configuration issues before they produce bad retrieval results.

## What this is for

- Documents embedded without chunking strategy (context dilution)
- Query and document embeddings from different models (semantic mismatch)
- Chunk size inappropriate for content type (too large = noise, too small = lost context)
- **Read-only skill.** No code changes.

## What You Must Do When Invoked

If `/embed-quality -help` or `/embed-quality -h` (without further arguments)
is invoked: output the `## Usage` section unchanged and stop.

Otherwise follow these steps in order, skipping none.

### Step 1 - Clarify target

Clarify `-ProjectDir`. Get confirmation.

### Step 2 - Scan

```powershell
& "<SKILL_DIR>/scripts/embed-scan.ps1" -ProjectDir "<path>"
```

### Step 3 - Classification

Read each embedding config:

- **Consistent**: appropriate chunk size, model parity, adequate overlap
- **Suboptimal**: room for improvement but functional
- **Mismatched**: query/doc model difference, no overlap
- **Broken**: will produce bad retrieval results

### Step 4 - Write report

File `embedding-quality-report.md` in current working directory:

1. **Summary** - embeddings by classification.
2. **Embedding table** - broken first. Per embedding: file, line, model, chunk size, overlap, has model parity, recommendation.
3. **Open questions**.

### Step 5 - Summarize

State report path, highlight embeddings that will produce bad retrieval.

## Usage

```
/embed-quality               # interactive
/embed-quality <dir>         # scan project
/embed-quality -help
```
