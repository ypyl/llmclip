## Why

`OpenAIProvider` and `OllamaProvider` each contain an identical 12-line `if-else` chain that maps tool name strings to `GetOpenAiToolDefinition()` calls. This duplicates 6 tool names across 2 files, making tool addition error-prone (must be updated in three places: `App.ahk` toolDefs, `LLMService.ConfigureToolSettings`, and both providers). The `toolsMap` in `LLMService` already maps name → tool instance — it's the natural single-source-of-truth.

## What Changes

- **LLMService.SendToLLM**: Expand tool name list into definition objects before passing to LLMClient, using the existing `toolsMap`
- **LLMService.ConfigureToolSettings**: Return expanded tool definitions directly alongside (or instead of) the raw name list
- **OpenAIProvider.GetRequestBody**: Replace 12-line `if-else` chain with direct assignment from settings
- **OllamaProvider.GetRequestBody**: Same replacement
- Remove the 6 `#Include` lines of tool classes from both provider files (no longer needed since providers don't reference tool classes directly)

## Capabilities

### New Capabilities
- `tool-def-passthrough`: LLM providers receive pre-resolved tool definitions instead of tool name strings — single-source-of-truth at the LLMService level

### Modified Capabilities
<!-- None — purely internal refactor, no behavior change -->

## Impact

- **Affected code**: `LLMService.ahk`, `OpenAIProvider.ahk`, `OllamaProvider.ahk`
- **No API/contract changes**: Input/output of providers unchanged; same tool definitions produced
- **No config changes**: `providers.json`, `keys.ini`, system prompts unaffected
- **No breaking changes**: Internal refactor only
