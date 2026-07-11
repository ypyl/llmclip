## Why

`LLMClient.GetProvider` hardcodes a 7-branch `if-else` chain matching 14 provider name strings to 4 internal provider types (`openai`, `ollama`, `google`, `audio`). This means adding a provider requires touching both `providers.json` AND `LLMClient.ahk`. The mapping should live in `providers.json` — add a `provider_type` field to each provider, and `GetProvider` simply reads it.

## What Changes

- Add `"provider_type"` field to each of the 9 providers in `providers/providers.json` (`"openai"`, `"ollama"`, `"google"`, or `"audio"`)
- Replace the 7-branch `if-else` in `LLMClient.GetProvider` with a direct lookup: `settings["provider_type"]` → `this.providers[t]`
- `Providers.ahk` automatically propagates provider-level keys to model configs, so no code change needed there

## Capabilities

### New Capabilities
- `provider-type-config`: Provider API type is declared in `providers.json`, not hardcoded in LLMClient

### Modified Capabilities
<!-- None — config addition, no behavior change -->

## Impact

- **Affected code**: `providers/providers.json` (+9 key-value pairs), `LLMClient.ahk` (−12 lines)
- **No breaking change**: same routing behavior, same error throwing on unknown type
- **Config change**: `providers.json` format extended — backward-compatible (unknown keys ignored by existing code)
