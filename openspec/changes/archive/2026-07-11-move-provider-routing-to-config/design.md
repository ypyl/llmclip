## Context

`LLMClient.GetProvider` currently maps provider names → internal types:

| Provider names | Internal type |
|---------------|---------------|
| Groq, GitHub, OpenCodeGo, OpenRouter, OpenAI, Azure, Nvidia | `openai` |
| OllamaLocal, OllamaCloud | `ollama` |
| GroqAudio, Groq Audio, Audio | `audio` |
| Google | `google` |

Each provider entry in `providers.json` already has all configuration (curl template, models, tool support) except which internal provider type to route to. Adding this as a `provider_type` field makes `providers.json` the single source of truth for all provider configuration.

## Goals / Non-Goals

**Goals:**
- Declare internal provider type in `providers.json`
- Simplify `GetProvider` to a direct map lookup
- No new providers to add at this time

**Non-Goals:**
- No change to how providers are loaded/merged
- No new provider types

## Decisions

**Decision: Use key `provider_type` (not `type`) to avoid conflict.**

`ConfigurationService.GetSelectedSettings` already sets `settings["type"]` to the full model path (`"Groq/llama-3.3-70b"`), which overwrites any `"type"` from providers.json. Using `"provider_type"` avoids the collision.

**Decision: `Providers.ahk` needs no changes.**

On line 30, `Providers.__New` copies all non-`"models"` keys from the provider config to `entry`. On line 43-44, these are merged into each model's config. So a new `"provider_type"` key at the provider level automatically propagates to `settings["provider_type"]` without code changes.

## Risks / Trade-offs

- **Config format change**: `providers.json` is user-editable but shipped with the binary. This adds 9 lines (one per provider). Backward-compatible — old `providers.json` without `provider_type` would use the default `"openai"` fallback in GetProvider.
