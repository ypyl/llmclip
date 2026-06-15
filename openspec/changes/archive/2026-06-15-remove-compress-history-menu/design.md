## Context

The History menu bar entry contains exactly one item ("Compress"). This triggers a multi-layer flow: `MainController.CompressHistory()` → `CompressHistoryCommand` → `LLMService.CompressHistory()` → curl call to LLM → `SessionManager.ReplaceWithCompressed()`. The feature has a dedicated `ProcessingState.COMPRESSING`, a menu-state command (`GetCompressionMenuStateCommand`), and a spec (`compression-service`). Despite this infrastructure, `GetCompressionPrompt()` always returns a hardcoded string (menu is perpetually enabled), indicating the feature never received runtime config integration and is unused.

The History menu itself is the only single-item top-level menu — all others have 2+ items. Removing the compress feature leaves an empty menu, so the menu entry goes too.

## Goals / Non-Goals

**Goals:**
- Remove all compress-related code across all layers (View, Controller, Command, Service)
- Remove the History menu bar entry (now empty)
- Simplify `SetProcessingState()` from 5 branches to 4
- Remove `ProcessingState.COMPRESSING` constant
- Delete the `compression-service` spec
- Zero runtime or compile-time regressions

**Non-Goals:**
- History View (chat-history ListView, Delete/Copy/`<`/`>`/Clear buttons) — unrelated, stays
- Other history commands (ClearHistory, GetHistoryListItems, NavigateHistory, DeleteMessage, etc.) — unrelated, stay
- Session navigation — unrelated
- Any UI redesign beyond removing the menu entry

## Decisions

### Decision 1: Remove both compress AND the History menu

**Rationale**: The History menu has one item. Removing compress makes the menu empty. An empty top-level menu is worse than no menu. Removing the entire menu entry is the only clean option.

**Alternatives considered**:
- Keep empty menu: Degraded UX, user confusion
- Add other items to History menu: Out of scope, feature creep

### Decision 2: Remove service-layer compress methods entirely

**Rationale**: `FormatMessagesForCompression{,ForSession}` and `ReplaceWithCompressed{,ForSession}` in `SessionManager.ahk` are only called by `CompressHistoryCommand`. `LLMService.CompressHistory()` is only called by that command. No other callers exist (verified via grep). Removing them is dead-code elimination.

**Alternatives considered**:
- Keep methods with deprecation comment: Pointless — AHK has no deprecation mechanism, dead code is just dead code

### Decision 3: Remove `ProcessingState.COMPRESSING` constant

**Rationale**: Only referenced by `MainController.CompressHistory()` and `SetProcessingState()`. After removal, `SetProcessingState()` drops from 5 branches (IDLE, PROCESSING, TOOL_PENDING, TOOL_RUNNING, COMPRESSING) to 4.

**Alternatives considered**:
- Keep constant for future use: YAGNI — if needed later, git history has it

### Decision 4: Delete entire `compression-service` spec

**Rationale**: The spec defines requirements for a feature being removed. No delta — just deletion. The delta spec file at `specs/compression-service/spec.md` documents all requirements as REMOVED with migration notes.

### Decision 5: Removal order — top-down by dependency

**Rationale**: To avoid compilation errors during implementation, removal starts at the highest layer (View) and moves downward (Controller → Command → Service → Composition Root). Within each file, remove in this order to keep dependent code compiling until its turn.

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| Residual references cause AHK parse errors at startup | Final step: `grep -rn -i "compress" --include="*.ahk" .` to verify zero matches |
| Someone relies on compress in their workflow | Feature was never properly integrated (hardcoded prompt), making this unlikely. Git history preserves the code. |
| `#Include` removal misses a transitive dependency | Compress command files are leaf nodes — nothing else includes them. Verified by checking all `#Include` directives. |
| SettingsController constructor parameter count changes | `App.ahk` is the only caller; counts are updated atomically |

## Open Questions

None — the scope is well-defined from the exploration analysis. All callers and dependencies have been mapped.
