# llm-cost-controller

Static analyzer for LLM cost optimization. Detects expensive model usage, unlimited tokens, high temperature, missing caching, batchable calls, and more.

## Usage

```powershell
& .\scripts\llm-cost-scan.ps1 -ProjectDir ".\my-ai-app"
& .\scripts\llm-cost-scan.ps1 -ProjectDir ".\my-ai-app" -MonthlyCallEstimate 50000
```

## Checks (8 total)

| Severity | Checks |
|---|---|
| high | expensive-model, no-max-tokens |
| medium | high-temperature, no-retry-backoff, no-caching, batchable-calls |
| low | large-context, streaming-not-used |

## Pricing Reference

Models priced per 1K tokens (input/output): GPT-4o ($2.50/$10), GPT-4o-mini ($0.15/$0.60), GPT-4 ($30/$60), Claude 3.5 Sonnet ($3/$15), Gemini 1.5 Flash ($0.075/$0.30).

## Trigger

`/llm-cost`
