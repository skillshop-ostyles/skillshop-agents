# Data Flow Cartographer — /dataflow

Traces data from input sources (API endpoints, events, files) through transformations to sinks (DB, APIs, logs, filesystem). Generates Mermaid flow diagrams per data flow with origin, schema changes, validation gaps, and security relevance.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/understanding/data-flow-cartographer ~/.claude/skills/
```

## Usage

```
/dataflow                          # interactive
/dataflow <dir>                    # scan project
```

## How It Works

1. **Input detection** — HTTP handlers (`app.post`, `@Post`), event listeners (`.on('event')`), file reads (`fs.readFile`)
2. **Sink detection** — DB calls (`.create()`, `prisma.*`), HTTP outbound (`fetch`, `axios`), file writes (`fs.writeFile`), logs (`console.log`)
3. **Assignment tracing** — Maps variable definitions within ±5 lines to sink arguments (up to 3 hops)
4. **Validation check** — Paths containing `if`/`typeof`/`validate` are marked as validated

## Output

Console summary and JSON with `flows[]` array. LLM generates `dataflow-report.md` with Mermaid diagrams.
