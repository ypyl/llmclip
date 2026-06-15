## Context

Batch Mode is a feature that lets users process a prompt against multiple checked context items independently — each item gets its own copy of message history and its own LLM response. It was added early in development but never gained traction. It has no active users and has silently accumulated two critical bugs (stub crash, missing label method) that went undetected precisely because the feature is unused.

The feature touches every architectural layer:
- **View**: `MenuView` has a dedicated `modeMenu` submenu ("Mode > Batch Mode")
- **Controller**: `MainController` routes `AskToLLM()` to batch vs. normal send, plus `ToggleBatchMode()` handler
- **Commands**: `ToggleBatchModeCommand`, `SendBatchToLLMCommand`
- **Service**: `SessionManager` has `batchModeEnabled` state, `SetBatchMode()`, `GetMessagesExcludingBatch*()` filter, `GetCheckedContextItems()`
- **Utils**: `MessagePresentationService` decorates batch messages with `🔄 [Batch]` / `✅ [label]` prefixes
- **Types**: `ChatMessage.ToObject()` filters `isBatchMode`, `isBatchResponse`, `batchContextItem` from API calls
- **Persistence**: `SaveStateOnExitCommand` / `LoadStateOnStartCommand` persist/restore `batchMode`

## Goals / Non-Goals

**Goals:**
- Delete all batch mode code — commands, controller routing, service state, view menu, presentation decorators
- Simplify `SendToLLMCommand` by removing the batch-message filtering step
- Remove the empty "Mode" menu from the menu bar
- Clean up `state.json` format (stop writing `batchMode` key)

**Non-Goals:**
- No replacement feature — batch mode is simply being removed
- No changes to normal send flow beyond removing the batch filter call
- No changes to context item checking behavior (checkboxes remain; they're just not used by batch mode anymore)
- Archive changes stay untouched (historical records)

## Decisions

### 1. Full removal vs. hiding the menu

**Choice:** Full removal of all batch code across all layers.

**Alternatives considered:**
- *Hide menu only*: Leaves dead code in 9 files, risk of future bugs from stale state/complexity. Rejected.
- *Deprecation period*: No users to notify, no migration needed. Added complexity for zero benefit. Rejected.

**Rationale:** Dead code is a maintenance liability. The architecture is clean — re-adding batch mode from git history would be straightforward if the need arises. Every removed line is a line that can't break.

### 2. Remove `GetMessagesExcludingBatch*()` entirely

**Choice:** Delete both `GetMessagesExcludingBatchForSession()` and its wrapper `GetMessagesExcludingBatch()` from `SessionManager`. In `SendToLLMCommand`, call `GetSessionMessages()` directly.

**Rationale:** These filter methods only strip messages tagged with `isBatchMode` / `isBatchResponse`. With batch mode removed, no message will ever carry those flags. The filter becomes a no-op. Keeping it would be confusing — future developers might wonder what it filters and why.

### 3. Remove `GetCheckedContextItems()` from SessionManager

**Choice:** Delete it.

**Rationale:** This method has zero remaining callers after batch mode's removal. Context item checking (the `Checked` property and `SetContextItemChecked()`) stays — those are general context management, not batch-specific.

### 4. Remove the entire "Mode" menu

**Choice:** Delete `modeMenu` from `MenuView` and the `this.menuBar.Add("Mode", ...)` line.

**Rationale:** Batch Mode was the sole item in the Mode menu. An empty menu column serves no purpose. Adding a future mode feature would require new menu wiring regardless, so there's no advantage to keeping an empty placeholder.

### 5. Clean `internalProps` in Types.ahk

**Choice:** Remove `isBatchMode`, `isBatchResponse`, `batchContextItem` from the `internalProps` array in `ChatMessage.ToObject()`.

**Rationale:** These properties will never be set again. Removing them from the filter list is safe — even if old persisted conversations (from `state.json` or saved conversations) carry these properties, they'd be harmless noise in API payloads. But since we're cleaning house, remove them.

## Risks / Trade-offs

- **[Risk] Saved conversations may contain batch-flagged messages** → **Mitigation**: The `internalProps` filter in `ChatMessage.ToObject()` will naturally skip any leftover batch flags since they won't be in the list. Messages display normally — the `MessagePresentationService` decorator is gone, so they render without `🔄 [Batch]` / `✅ [label]` prefixes. No migration needed.

- **[Risk] `state.json` may have `batchMode` key from previous sessions** → **Mitigation**: `LoadStateOnStartCommand` checks `Has("batchMode")` before attempting to read it. After this change, that block is removed, so the old key is simply ignored. `SaveStateOnExitCommand` stops writing it, so new state files won't have it.

- **[Risk] Breaking the normal send flow** → **Mitigation**: The only change to the normal send path is replacing `GetMessagesExcludingBatchForSession()` with `GetSessionMessages()` in `SendToLLMCommand`. This is behaviorally identical since batch-flagged messages no longer exist. Manual smoke test: send a prompt normally after removal, confirm response renders correctly.
