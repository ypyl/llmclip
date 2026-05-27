## Why

`SendBatchToLLMCommand` constructs a stub `tempSession` object to pass to `LLMService.SendToLLM()`, but the stub uses the wrong method name (`GetSessionLLMType` instead of `GetSessionModelIndex`). This causes a runtime crash whenever batch mode is used. The root cause is a fragile duck-typing pattern: `LLMService.SendToLLM()` depends on the full `SessionManager` interface when it only needs a messages array and a model index. When the real `SessionManager` was refactored (method renamed), the stub was silently broken.

## What Changes

- **BREAKING**: `LLMService.SendToLLM()` signature changed — replaces `(sessionManager, ..., sessionIndex)` parameters with `(messages, modelIndex, ...)`. Callers now extract messages and model index from the session before calling.
- `SendToLLMCommand.Execute()` extracts messages and model index, passes them directly to the service.
- `SendBatchToLLMCommand.Execute()` passes cloned messages and model index directly — the entire `tempSession` stub object is deleted.
- No other callers of `LLMService.SendToLLM()` exist, so no further changes needed.

## Capabilities

### New Capabilities
- `batch-mode`: Batch mode LLM calls complete successfully without crashing. The LLM service accepts messages and model index directly rather than extracting them from a session manager interface.

### Modified Capabilities
<!-- None — this is a bug fix and internal API refactor. No external behavior changes. -->

## Impact

- **Modified**: `Services\LLM\LLMService.ahk` — `SendToLLM()` signature and implementation
- **Modified**: `Commands\SendToLLMCommand.ahk` — extract messages/modelIndex before calling service
- **Modified**: `Commands\SendBatchToLLMCommand.ahk` — remove stub object, pass messages/modelIndex directly
- **No changes** to views, controllers, other commands, or other services
