## Context

`LLMService.CompressHistory()` and `LLMService.ExtractLearnings()` currently accept a `SessionManager` instance and internally extract four pieces of data: messages, conversation text, model index, and compression/learnings prompt. Meanwhile, both `CompressHistoryCommand` and `ExtractLearningsCommand` already extract the same data before calling the service for validation purposes — then discard it and pass the raw `sessionManager` to the service, which re-extracts everything.

This follows the same anti-pattern fixed in `fix-batch-mode-stub-crash`: the service depends on a large interface (`SessionManager`) when it only needs a few values. Both commands and services duplicate validation and extraction logic.

## Goals / Non-Goals

**Goals:**
- Eliminate duplicated validation and data extraction between commands and service
- Decouple `CompressHistory()` and `ExtractLearnings()` from `SessionManager` so they accept pre-extracted data
- Keep prompt building (compression prompt, learnings prompt) as service-owned domain logic

**Non-Goals:**
- Do NOT change the LLM call logic, temp message construction, or return types
- Do NOT refactor `CompressHistoryCommand` state mutation (`ReplaceWithCompressedForSession`)
- Do NOT touch the `MainController` orchestration that calls these commands

## Decisions

### Decision 1: Service accepts messages, conversationText, modelIndex

```ahk
CompressHistory(messages, conversationText, modelIndex)
ExtractLearnings(messages, conversationText, modelIndex)
```

Both methods need the same three inputs. The service fetches compression/learnings prompts from `configManager` using `modelIndex`, appends `conversationText`, builds temp messages, and calls the LLM.

**Rationale**: Follows the established pattern from `SendToLLM(messages, modelIndex, ...)`. Prompt building remains in the service where it belongs. The commands own data extraction from the session.

**Alternative considered**: `CompressHistory(systemMessage, assembledPrompt, modelIndex)` — pushing prompt assembly into the command. Rejected because prompt composition (which config to fetch, how to append conversation text) is domain logic that belongs in the service.

### Decision 2: Move all validation into the service

The commands currently validate message count and conversation text emptiness, then the service does the same checks. After the refactor, only the service validates.
The command's responsibility is: extract data → call service → mutate state.

**Rationale**: Single source of truth for validation. If validation needs to change, it changes in one place. The service throws descriptive errors that bubble up through the command to the controller's error handling.

### Decision 3: Remove sessionIndex parameter

With `sessionManager` removed, the `sessionIndex` parameter (used only to default from `sessionManager.currentSessionIndex`) is also removed. The caller already knows the target session index and can extract data from it directly.

## Risks / Trade-offs

**Risk**: The command's `GetCompressionPrompt()` call used the model index from config, but now the service does that internally. If the config changes between command extraction and service call, the prompt might differ.  
→ **Mitigation**: This is the same risk that existed before (the command built a prompt for validation, the service rebuilt it for execution). In practice, config doesn't change mid-operation, and the service is now the single authority.

**Risk**: `ExtractLearningsCommand` currently doesn't extract `modelIndex` (it passes `sessionManager` to the service which extracts it). Adding `modelIndex` extraction adds one `GetSessionModelIndex()` call.  
→ **Mitigation**: This is a trivial read — the same call `CompressHistoryCommand` already makes. No performance or correctness concern.
