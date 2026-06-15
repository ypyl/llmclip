## Why

Batch Mode (Mode > Batch Mode) is completely unused. It has accumulated two critical runtime bugs in the past year (stub crash, missing label method) that went unnoticed precisely because no one uses it. The feature adds complexity across all four architectural layers — commands, controller, service, views — plus state persistence and message presentation. Removing it simplifies the codebase and eliminates a maintenance burden.

## What Changes

- **Remove the "Mode" menu** from the menu bar entirely (Batch Mode was its only item)
- **Delete two commands**: `SendBatchToLLMCommand` and `ToggleBatchModeCommand`
- **Remove `batchModeEnabled` state** from `SessionManager`, along with `SetBatchMode()` and `GetMessagesExcludingBatch*()` filter methods
- **Remove `GetCheckedContextItems()`** from `SessionManager` (only used by batch mode)
- **Simplify `SendToLLMCommand`**: use `GetSessionMessages()` directly instead of `GetMessagesExcludingBatchForSession()`
- **Remove batch indicator decoration** from `MessagePresentationService`
- **Clean `ChatMessage.ToObject()` internalProps**: remove `isBatchMode`, `isBatchResponse`, `batchContextItem`
- **Remove batch state persistence** from save/load state commands
- **Delete `openspec/specs/batch-mode/spec.md`**
- **Update README** to remove batch mode mentions

## Capabilities

### New Capabilities

None — this is a pure removal.

### Modified Capabilities

- `batch-mode`: **REMOVED**. The entire capability is being deleted. All batch mode functionality — toggling via menu, iterating prompts over checked context items, batch-specific message flags and presentation — is removed.

## Impact

- **Deleted files** (2): `Commands/SendBatchToLLMCommand.ahk`, `Commands/ToggleBatchModeCommand.ahk`
- **Modified files** (9): `App.ahk`, `MainController.ahk`, `MenuView.ahk`, `SessionManager.ahk`, `SendToLLMCommand.ahk`, `SaveStateOnExitCommand.ahk`, `LoadStateOnStartCommand.ahk`, `MessagePresentationService.ahk`, `LLM/Types.ahk`
- **Docs**: `README.md` — remove 2 mentions of batch mode
- **Specs**: `openspec/specs/batch-mode/spec.md` — deleted
- **No breaking changes to normal send flow**, no API/keys/config changes
- **Verification**: run `main.ahk`, confirm menu bar has no Mode menu, send a prompt normally
- **Rollback**: revert the commit — pure deletion, no data migration needed
