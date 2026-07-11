## 1. providers.json — add provider_type

- [x] 1.1 Add `"provider_type"` to each of the 9 providers: GitHub/Groq/OpenRouter/Nvidia/OpenCodeGo → `"openai"`, OllamaLocal/OllamaCloud → `"ollama"`, Google → `"google"`, GroqAudio → `"audio"`

## 2. LLMClient — simplify GetProvider

- [x] 2.1 Replace the 7-branch `if-else` chain in `GetProvider` with `t := settings.Get("provider_type", "openai")` → `this.providers[t]` lookup
- [x] 2.2 Run `main.ahk` — switch between providers, verify routing works
