# Cluster ai-ml - Artificial Intelligence and Machine Learning

Skills in this cluster help secure and manage AI/ML integrations: detecting
prompt injection vulnerabilities, controlling LLM costs, auditing prompt
quality, tracking model drift, and ensuring responsible AI usage across the
pipeline. Phase C expanded the cluster from 2 to 14 skills.

## Skills in this Cluster

| Skill | Trigger | Audience | Purpose |
|--|--|--|--|
| [prompt-injection-detector](../ai-ml/prompt-injection-detector/) | /prompt-inspect | Senior > Vibe | Static analysis for prompt injection: find LLM API calls, trace untrusted data into prompts, classify countermeasures. |
| [llm-cost-controller](../ai-ml/llm-cost-controller/) | /llm-cost | Senior | Audit LLM API calls for cost anti-patterns: expensive models, unlimited tokens, no caching, batchable calls. Estimates monthly spend and savings potential. |
| [prompt-quality-auditor](../ai-ml/prompt-quality-auditor/) | /prompt-quality | Both | Audit prompt structure, specificity, and injection susceptibility across all LLM calls. |
| [embedding-quality-scanner](../ai-ml/embedding-quality-scanner/) | /embed-quality | Senior | Scan embedding chunking strategy, model parity, and configuration for quality gaps. |
| [training-data-leakage-detector](../ai-ml/training-data-leakage-detector/) | /train-leak | Senior | Detect data leakage in ML training pipelines: temporal leaks, label leaks, and cross-validation contamination. |
| [model-output-guardrail-auditor](../ai-ml/model-output-guardrail-auditor/) | /guardrails | Senior | Audit model output consumption for safety gaps: where LLM output is used without validation, sanitization, or oversight. |
| [prompt-drift-tracker](../ai-ml/prompt-drift-tracker/) | /prompt-drift | Senior | Track prompt changes across git history for semantic drift, regression, and unintended behavior changes. |
| [token-budget-analyzer](../ai-ml/token-budget-analyzer/) | /token-budget | Both | Analyze static code for token usage waste and budget risks in LLM API calls. |
| [rag-pipeline-consistency-auditor](../ai-ml/rag-pipeline-consistency-auditor/) | /rag-consistency | Senior | Audit RAG pipeline configuration for embedding model drift, chunking mismatch, and retrieval consistency issues. |
| [llm-call-observability-gap](../ai-ml/llm-call-observability-gap/) | /llm-obs | Senior | Find LLM API calls lacking observability coverage: missing logging, tracing, or monitoring. |
| [ai-decision-logger](../ai-ml/ai-decision-logger/) | /ai-log | Senior | Find model-based decision points missing audit logging: classification, routing, or generation decisions made without traceability. |
| [tool-call-fidelity-checker](../ai-ml/tool-call-fidelity-checker/) | /tool-fidelity | Senior | Check tool/function definitions for hallucination-prone schemas: ambiguous descriptions, missing constraints, type mismatches. |
| [fine-tune-dependency-check](../ai-ml/fine-tune-dependency-check/) | /finetune-deps | Senior | Find fine-tuned model references with deprecated base models, missing version pins, or unmaintained adapters. |
| [ml-pipeline-determinism-check](../ai-ml/ml-pipeline-determinism-check/) | /ml-determinism | Senior | Find sources of non-determinism in ML training pipelines: unseeded RNGs, non-deterministic ops, data shuffle without fixed seed. |

## Cross-Links

- `security/` - `prompt-injection-detector` (ai-ml) and `input-validation-audit` (security) share common validation patterns.
- `quality/` - `code-clone-detector` (quality) shares fingerprinting techniques with `prompt-drift-tracker` (ai-ml).
