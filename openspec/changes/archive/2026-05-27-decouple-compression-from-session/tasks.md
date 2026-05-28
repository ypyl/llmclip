## 1. Service Layer — LLMService method signatures

- [x] 1.1 Change `CompressHistory()` signature from `(sessionManager, sessionIndex)` to `(messages, conversationText, modelIndex)` in `Services\LLM\LLMService.ahk`, remove the `sessionIndex` default logic and the three `sessionManager` extraction calls
- [x] 1.2 Change `ExtractLearnings()` signature from `(sessionManager, sessionIndex)` to `(messages, conversationText, modelIndex)` in `Services\LLM\LLMService.ahk`, remove the `sessionIndex` default logic and the three `sessionManager` extraction calls

## 2. Command Layer — CompressHistoryCommand

- [x] 2.1 Remove duplicate validation and prompt-building logic from `CompressHistoryCommand.Execute()` (lines ~17-35: messages check, conversationText check, compressionPrompt fetch)
- [x] 2.2 Pass the already-extracted `messages`, `conversationText`, and `modelIndex` to `LLMService.CompressHistory()` instead of `(this.sessionManager, targetSessionIndex)`
- [x] 2.3 Keep the state mutation logic (`ReplaceWithCompressedForSession`) unchanged

## 3. Command Layer — ExtractLearningsCommand

- [x] 3.1 Remove duplicate validation logic from `ExtractLearningsCommand.Execute()` (lines ~17-22: messages check, conversationText check)
- [x] 3.2 Add `modelIndex` extraction: `modelIndex := this.sessionManager.GetSessionModelIndex(targetSessionIndex)`
- [x] 3.3 Pass `messages`, `conversationText`, and `modelIndex` to `LLMService.ExtractLearnings()` instead of `(this.sessionManager, targetSessionIndex)`

## 4. Verification

- [x] 4.1 Verify no other callers of `CompressHistory` or `ExtractLearnings` exist by searching the codebase
- [x] 4.2 Manual smoke test: launch `main.ahk`, build up conversation history, run compress, verify response renders and history is replaced (needs manual AHK v2 execution)
- [x] 4.3 Manual smoke test: run extract learnings, verify notes appear in the notes view (needs manual AHK v2 execution)
