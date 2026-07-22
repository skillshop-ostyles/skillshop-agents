# prompt-injection-detector

Static analyzer for prompt injection vulnerabilities in LLM-integrated applications. Detects API calls to OpenAI, Anthropic, Google Gemini, LangChain, Ollama, and generic endpoints. Traces untrusted data flow into system prompts and user messages. Classifies injection countermeasures.

## Installation

```powershell
& .\scripts\prompt-scan.ps1 -ProjectDir ".\my-ai-app"
```

## Requirements

- PowerShell 5.1+

## Usage

```powershell
# Full scan
& .\scripts\prompt-scan.ps1 -ProjectDir "C:\Projects\my-ai-app"

# Exclude test files
& .\scripts\prompt-scan.ps1 -ProjectDir "C:\Projects\my-ai-app" -Exclude "test,spec,fixture"
```

## What It Detects

| Provider | Patterns |
|---|---|
| OpenAI | `openai`, `chat.completions.create` |
| Anthropic | `anthropic`, `messages.create` |
| Google Gemini | `gemini`, `generateContent` |
| LangChain | `langchain`, `invoke`, `LLMChain` |
| Ollama | `ollama`, `/api/chat` |
| Generic | `model.`, `client.`, `/v1/chat/completions` |

## Trigger

`/prompt-inspect`
