## Context

`ConfigurationService` currently stores tool enable/disable state directly in the in-memory providers cache — the same `Map` structure built from `providers.json`. When `Reload()` is called (explicitly via Settings menu, or implicitly when `PromptCreatorTool` creates a prompt), the providers cache is rebuilt from JSON, wiping all user tool preferences.

The existing `state.json` persistence mechanism already saves and restores `modelIndex`, `systemPromptIndex`, `answerSize`, `batchMode`, and `sessionIndex`. Adding `toolOverrides` follows the same pattern.

## Goals / Non-Goals

**Goals:**
- Tool preferences survive `Reload()` calls and app restarts
- `providers.json` remains an immutable default — never mutated at runtime for user preferences
- Per-model overrides: toggling tools for one model does not affect other models
- Zero breaking changes to the `IsToolEnabled()` and `SetToolEnabled()` public API

**Non-Goals:**
- Do NOT modify `providers.json` or its format
- Do NOT change the Tools menu UI or controller logic
- Do NOT add a new config file — use existing `state.json`

## Decisions

### Decision 1: Store overrides in state.json with per-model keying

```json
{
  "modelIndex": 3,
  "systemPromptIndex": 1,
  "toolOverrides": {
    "Groq/llama-3.3-70b-versatile": {
      "execute_powershell": false,
      "web_search": true
    },
    "Google/gemini-2.5-flash": {
      "file_system": false
    }
  }
}
```

The key is the `"provider/model"` string (matching `this.models[modelIndex]`). Values are `toolName: boolean`.

**Rationale**: Per-model scoping is correct — different models support different tools. The key format matches the existing `models` array indexing. Storage in `state.json` reuses existing persistence infrastructure.

**Alternative considered**: Global overrides (one map for all models). Rejected — toggling a tool for one model shouldn't affect another model that may not even support that tool.

### Decision 2: Read logic — override first, default fallback

```ahk
IsToolEnabled(modelIndex, toolName) {
    ; Check user override first
    modelKey := this.models[modelIndex]
    if this.toolOverrides.Has(modelKey) && this.toolOverrides[modelKey].Has(toolName)
        return this.toolOverrides[modelKey][toolName]

    ; Fall back to provider default
    settings := this.GetSelectedSettings(modelIndex)
    tools := settings.Get("tools", [])
    ; ... existing logic ...
}
```

**Rationale**: Explicit user choice always wins. If the user has never toggled a tool, the provider default applies. This is consistent with how `answerSize` works (user picks "Small"/"Long"/"Default").

### Decision 3: SetToolEnabled writes to overrides, never to providers cache

```ahk
SetToolEnabled(modelIndex, toolName, enabled) {
    modelKey := this.models[modelIndex]
    if !this.toolOverrides.Has(modelKey)
        this.toolOverrides[modelKey] := Map()
    this.toolOverrides[modelKey][toolName] := enabled
}
```

The old logic that mutated `settings["tools"]` from the providers cache is removed entirely.

**Rationale**: Clean separation. Providers cache is read-only after `LoadAll()`. All mutations go through `toolOverrides`.

## Risks / Trade-offs

**Risk**: If a user upgrades from a version without this feature, their `state.json` will have no `toolOverrides` key.  
→ **Mitigation**: `LoadStateOnStartCommand` checks `Has("toolOverrides")` before reading. Absent key means no overrides — all tools use provider defaults. Graceful degradation.

**Risk**: If a model is removed from `providers.json`, its override entry in `state.json` becomes orphaned but harmless.  
→ **Mitigation**: No cleanup needed — unused overrides are inert. Orphaned entries could be cleaned on save, but the cost/benefit doesn't justify it.
