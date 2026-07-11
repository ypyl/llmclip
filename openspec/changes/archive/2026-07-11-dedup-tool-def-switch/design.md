## Context

Currently, `OpenAIProvider.GetRequestBody` and `OllamaProvider.GetRequestBody` each contain an identical 12-line block:

```autohotkey
for t in settings.Get("tools", []) {
    if (t = PowerShellTool.TOOL_NAME)
        enabledTools.Push(PowerShellTool.GetOpenAiToolDefinition())
    else if (t = FileSystemTool.TOOL_NAME)
        enabledTools.Push(FileSystemTool.GetOpenAiToolDefinition())
    ; ... 4 more branches
}
```

This requires each provider to `#Include` all 6 tool class files and hardcode the mapping. Adding a tool means touching 3 locations: `App.ahk` toolDefs, `LLMService.ConfigureToolSettings`, and both provider files. `LLMService` already owns a `toolsMap` (name → tool instance) — it can resolve definitions before they reach the provider.

## Goals / Non-Goals

**Goals:**
- Single maintenance point for tool name → definition resolution
- Remove duplicated `if-else` chains from both providers
- Remove 6 unnecessary `#Include` directives from each provider file

**Non-Goals:**
- No change to provider interface (`settings` Map key stays compatible)
- No change to tool definition format or behavior
- No new classes or wiring in `App.ahk`

## Decisions

**Decision 1: Expand in LLMService, not in providers.**

Alternatives considered:
- *Pass toolsMap to providers*: Requires new constructor parameter, wiring in App.ahk, changes LLMClient. More plumbing for a one-line loop.
- *Static lookup map in BaseProvider*: Another registry to sync when tools change. Defeats the purpose.
- *Expand in LLMService.SendToLLM*: `LLMService` already has `this.tools` (the toolsMap from App.ahk). One line resolves all definitions. Settings carry the resolved array natively. Simplest diff.

**Decision 2: Use `settings["tools"]` key with expanded definitions, not a new key.**

Existing settings flow: `settings["tools"]` = array of tool name strings → provider iterates. After change: `settings["tools"]` = array of pre-resolved definition objects (same format, just expanded earlier). Providers change from `if-else` to direct assignment: `body["tools"] := settings["tools"]`. Zero new keys, zero provider-side logic.

**Decision 3: Keep `ConfigureToolSettings` returning name strings internally, expand in `SendToLLM`.**

`ConfigureToolSettings` is also called from `LLMService.ConfigureToolSettings` (used externally to compute enabled tool list). Changing its return type would have ripple effects. Instead, expand only in `SendToLLM` which is the sole path to providers.

## Risks / Trade-offs

- **Order-preserving**: The existing code iterates settings["tools"] in order; the new loop over toolsMap preserves that same iteration order since settings["tools"] drives which keys to look up.
- **Missing tool**: If settings["tools"] contains a name not in toolsMap, the old code silently skipped it (no matching `if`). New code would throw on a missing map key. Mitigation: gate with `if this.tools.Has(t)` — one extra check.
- **No rollback needed**: Refactor is purely internal. If providers' tool definition array is identical (verified by eye), behavior is unchanged.
