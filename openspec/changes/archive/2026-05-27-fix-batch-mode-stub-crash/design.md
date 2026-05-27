## Context

`LLMService.SendToLLM()` currently takes a `sessionManager` parameter to extract two pieces of data internally: the messages to send and the model index for provider settings. This forces all callers to provide a `SessionManager`-shaped object, even when the caller is operating on cloned or synthetic message sets (batch mode).

`SendBatchToLLMCommand` works around this by constructing a stub plain object `tempSession` that mimics the `SessionManager`'s interface. This stub became broken when `GetSessionLLMType` was renamed to `GetSessionModelIndex` in the real `SessionManager` — the stub was never updated. Batch mode crashes with a property-not-found error.

The stub is the **only** place in the codebase where a fake `SessionManager` is constructed. Every other caller passes the real instance.

## Goals / Non-Goals

**Goals:**
- Fix the batch mode crash by eliminating the fragile stub object
- Make `LLMService.SendToLLM()` honest about its actual dependencies (messages + model index, not a full session manager)
- Keep the change minimal and mechanical — no behavioral changes to any feature

**Non-Goals:**
- Do NOT touch `CompressHistory()` or `ExtractLearnings()` — those are separate concerns (see audit S1/S2)
- Do NOT change how batch mode messages are built, cloned, or collected
- Do NOT change the auto-approval loop or tool execution paths
- Do NOT add tests or linting infrastructure

## Decisions

### Decision 1: Extract data in the caller, not the service

`LLMService.SendToLLM()` currently does this internally:
```ahk
messages := sessionManager.GetMessagesExcludingBatchForSession(sessionIndex)
modelIndex := sessionManager.GetSessionModelIndex(sessionIndex)
```

The new design has the **caller** extract these values and pass them directly:
```ahk
; New signature:
SendToLLM(messages, modelIndex, answerSize, powerShellEnabled, ...)
```

**Rationale**: The service should not know how to extract messages from a session — that's orchestration logic that belongs in the command layer. This aligns with the architecture rule that Services contain pure domain logic, not orchestration.

**Alternative considered (Path A)**: Simply rename `GetSessionLLMType` to `GetSessionModelIndex` in the stub. Rejected because the stub pattern is inherently fragile — any future change to what `SendToLLM` reads from `sessionManager` will silently break batch mode again.

### Decision 2: Remove `sessionIndex` parameter

The `sessionIndex` parameter existed solely to default from `sessionManager.currentSessionIndex` when zero. With `sessionManager` removed, `sessionIndex` serves no purpose. The caller already knows which session it's operating on and can pass the correct messages directly.

**Rationale**: Simplifies the interface. The one caller that used a non-zero session index (`SendToLLMCommand` for regeneration on a target session) already computes that index before calling.

### Decision 3: Keep `messages` as a mutable array parameter

`SendToLLM` performs two in-place mutations on the messages array:
1. Appends date/time to the system message content
2. Temporarily pushes/removes an answer-size instruction message

Both mutations affect `ChatMessage` instances shared with the caller's array. This behavior is unchanged — the caller passes its array and the service mutates the same object references.

**Rationale**: Zero behavioral change. The system message mutation persists correctly (same object references). The temporary push/remove happens on an array the caller controls, same as before.

## Risks / Trade-offs

**Risk**: The answer-size instruction message is pushed to the caller's array and removed after the LLM call. If the LLM call fails between push and remove, the instruction message could be left in the array.  
→ **Mitigation**: This is pre-existing behavior (not introduced by this change). The `try/catch` already around the LLM call prevents this, and even if it did happen, it's a benign one-message leak in the caller's local array.

**Risk**: Future callers might pass the wrong model index.  
→ **Mitigation**: The model index is validated by `ConfigurationService.GetSelectedSettings()` which returns an empty Map for out-of-range indices. The LLM call will fail with a clear error. This is the same validation that existed before.

**Risk**: `SendToLLMCommand` currently accesses `sessionManager` for context building, and we're adding more `sessionManager` calls (for extracting messages/modelIndex). This could make the command too "smart".  
→ **Mitigation**: The new calls (`GetMessagesExcludingBatchForSession`, `GetSessionModelIndex`) are simple property reads, not business logic. The command already does significant session interaction (building user messages, adding results). This change is consistent with existing patterns.

## Migration Plan

1. Change `LLMService.SendToLLM()` signature and body
2. Update `SendToLLMCommand.Execute()` to extract data before calling
3. Update `SendBatchToLLMCommand.Execute()` to remove stub and pass data directly
4. Manual smoke test: send a message normally, send in batch mode

**Rollback**: Revert to the previous signature. The old code has the bug, but normal (non-batch) mode works correctly. No data migration needed.
