## Why

`CompressHistoryCommand` and `ExtractLearningsCommand` duplicate all validation and data-extraction logic that `LLMService.CompressHistory()` and `LLMService.ExtractLearnings()` perform internally. The commands extract messages, conversation text, model index, and compression prompt from the session manager, validate them, then call the service — which re-extracts and re-validates the same data from scratch. This is wasted computation and a maintenance risk: if the validation logic diverges between command and service, bugs emerge silently. Following the same pattern established in `fix-batch-mode-stub-crash`, the service methods should accept the data they need directly rather than pulling it from a `SessionManager` instance.

## What Changes

- **BREAKING**: `LLMService.CompressHistory()` signature changed from `(sessionManager, sessionIndex)` to `(messages, conversationText, modelIndex)`.
- **BREAKING**: `LLMService.ExtractLearnings()` signature changed from `(sessionManager, sessionIndex)` to `(messages, conversationText, modelIndex)`.
- `CompressHistoryCommand.Execute()`: removes duplicate validation and data extraction (14 lines), passes already-extracted data to the service, keeps state mutation.
- `ExtractLearningsCommand.Execute()`: extracts `modelIndex` from session, passes data directly.
- No other callers of `CompressHistory()` or `ExtractLearnings()` exist.

## Capabilities

### New Capabilities
- `compression-service`: The compression and extraction LLM operations accept pre-extracted messages, conversation text, and model index directly, rather than depending on a `SessionManager` interface. Commands own data extraction; the service owns prompt building and LLM invocation.

### Modified Capabilities
<!-- None — internal API refactor, no external behavior change -->

## Impact

- **Modified**: `Services\LLM\LLMService.ahk` — `CompressHistory()` and `ExtractLearnings()` signatures and bodies
- **Modified**: `Commands\CompressHistoryCommand.ahk` — remove duplicate logic, pass extracted data
- **Modified**: `Commands\ExtractLearningsCommand.ahk` — extract modelIndex, pass extracted data
- **No changes** to controllers, views, or other services
