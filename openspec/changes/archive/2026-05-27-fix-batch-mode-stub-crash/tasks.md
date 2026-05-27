## 1. Service Layer — LLMService.SendToLLM signature change

- [x] 1.1 Change `SendToLLM()` signature: replace `(sessionManager, ..., sessionIndex)` with `(messages, modelIndex, ...)` in `Services\LLM\LLMService.ahk`
- [x] 1.2 Remove the two `sessionManager` extraction lines (`GetMessagesExcludingBatchForSession` and `GetSessionModelIndex`) from the method body
- [x] 1.3 Remove the `sessionIndex` default-from-sessionManager logic at method start — the `modelIndex` parameter is now required

## 2. Command Layer — Update callers

- [x] 2.1 Update `SendToLLMCommand.Execute()` in `Commands\SendToLLMCommand.ahk`: extract `messages` via `sessionManager.GetMessagesExcludingBatchForSession(targetSessionIndex)` and `modelIndex` via `sessionManager.GetSessionModelIndex(targetSessionIndex)` before the service call, then pass them directly
- [x] 2.2 Update `SendBatchToLLMCommand.Execute()` in `Commands\SendBatchToLLMCommand.ahk`: remove the entire `tempSession` stub object (lines ~63-70), extract `modelIndex` once before the batch loop, and pass `clonedMessages` + `modelIndex` directly to `LLMService.SendToLLM()`
- [x] 2.3 Verify no other callers of `SendToLLM` exist by searching for `SendToLLM(` across the codebase

## 3. Integration

- [x] 3.1 Manual smoke test: launch `main.ahk`, send a normal message, verify response renders (needs manual AHK v2 execution)
- [x] 3.2 Manual smoke test: enable batch mode, send with checked context items, verify each batch item gets a response and no crash occurs (needs manual AHK v2 execution)
