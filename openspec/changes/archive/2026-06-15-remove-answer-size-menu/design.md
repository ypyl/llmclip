## Context

The "Answer Size" feature lives as a top-level menu bar entry with three options (Small / Default / Long). Selecting an option flows through `SettingsController.SelectAnswerSize()` → `ChangeAnswerSizeCommand.Execute()` → `SessionManager.SetAnswerSize()`. On each LLM call, `SendToLLMCommand` reads `sessionManager.answerSize` and passes it to `LLMService.SendToLLM()`, which injects a verbosity instruction as an extra user message before the real conversation (and removes it after the response). The answer size value persists to `state.json` via `SaveStateOnExitCommand` and is restored on startup via `LoadStateOnStartCommand`.

The feature is a single-purpose vertical slice touching 8 files across all architectural layers. Its removal follows the same pattern as the recently archived `remove-compress-history-menu` change.

## Goals / Non-Goals

**Goals:**
- Remove the "Answer Size" menu entry from the menu bar (File, Session, Tools, Model remain)
- Delete `ChangeAnswerSizeCommand.ahk` entirely
- Remove `answerSize` field and setter from `SessionManager` — the only state owner for this feature
- Remove the answer-size parameter and 3-branch injection logic from `LLMService.SendToLLM()`
- Remove answer-size from state persistence (save/load commands)
- Clean up all wiring in `App.ahk`
- Zero runtime regressions — all LLM calls behave as prior "Default" mode (no injected verbosity instruction)

**Non-Goals:**
- Any other menu changes (File, Session, Tools, Model menus are untouched)
- Any UI redesign beyond removing the menu entry
- Any change to `LLMService.SendToLLM()` beyond dropping the `answerSize` param — the core LLM calling logic stays identical
- Removing `answerSize` from existing `state.json` files (ignored safely by updated loader)
- Tool menu, session navigation, or any other feature

## Decisions

### Decision 1: Remove the entire vertical slice, not just the menu UI

**Rationale**: The menu is the only entry point for answer size. There is no programmatic API, no hotkey, no other caller. Keeping the `answerSize` field and `SetAnswerSize()` in `SessionManager` with no caller is dead code. The architecture (strict layering) already prohibits Commands from being called outside the defined flow, so there's no plausible future reuse without re-adding the full chain.

**Alternatives considered**:
- Remove only the menu, keep the plumbing: Dead code in SessionManager, LLMService, and state persistence. Violates YAGNI and clutters the codebase.
- Keep the menu but repurpose it: Out of scope for this change. If a similar feature is needed later, it can be built from scratch (git history preserves current code).

### Decision 2: Remove `answerSize` parameter from `LLMService.SendToLLM()`

**Rationale**: After removing the menu, `answerSize` is always `"Default"`. The three-branch conditional (`if Small` / `if Long` / else nothing) always takes the "nothing" path. Removing the parameter simplifies the signature and eliminates dead branches.

**Alternatives considered**:
- Keep parameter, hardcode `"Default"` at the call site: Unnecessary complexity — a parameter that never varies is just noise.

### Decision 3: Removal order — top-down by dependency

**Rationale**: To avoid AHK parse errors during implementation (AHK has no incremental compilation), removal proceeds from highest layer to lowest:

```
View (MenuView) → Controller (SettingsController) → Command (ChangeAnswerSizeCommand)
    → Service (SessionManager, LLMService) → State Persistence → Composition Root (App.ahk)
```

Within each file, remove references in order of use (field → method body → constructor param → `#Include`).

This matches the proven pattern from `remove-compress-history-menu`.

### Decision 4: No spec delta needed

**Rationale**: The proposal lists zero new and zero modified capabilities. The answer-size feature has no corresponding spec in `openspec/specs/`. There are no requirement-level changes to document — the LLM calling behavior is identical to the prior "Default" mode.

### Decision 5: No migration needed for `state.json`

**Rationale**: `LoadStateOnStartCommand` already guards answer-size restoration with `state.Has("answerSize")`. After removal, the key simply won't be in newly saved state files. Existing state files with `"answerSize"` will have it silently ignored. No data migration required.

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| Residual references to `answerSize` cause AHK parse errors at startup | Final grep: `grep -rni "answersize\|answer.size\|answer_size" --include="*.ahk" .` to verify zero matches |
| SettingsController constructor parameter count changes | `App.ahk` is the only caller; all parameter order changes are atomic within the same edit |
| `#Include` removal misses a transitive dependency | `ChangeAnswerSizeCommand.ahk` is a leaf node — nothing `#Include`s it except `App.ahk`. Verified by checking all `#Include` directives across the codebase |
| User notices the menu is gone | The feature is redundant — users already control verbosity through prompt wording. The "Default" mode (no injection) was already the default, so behavior is unchanged |

## Open Questions

None — the scope is well-defined from exploration. All callers and dependencies have been mapped, and the pattern is validated by the prior `remove-compress-history-menu` change.
