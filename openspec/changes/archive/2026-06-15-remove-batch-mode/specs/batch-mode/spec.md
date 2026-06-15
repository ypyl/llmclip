## REMOVED Requirements

### Requirement: Batch mode sends messages without a stub session manager
**Reason**: Batch Mode is unused and being removed entirely to simplify the codebase. Deleting the feature means deleting all batch-specific behavior including message cloning, context item iteration, and batch response tagging.

**Migration**: No migration needed. The normal send flow (`SendToLLMCommand.Execute()`) continues to work identically. Checked context items remain functional outside of batch mode — checking items still works for the normal send flow.

#### Scenario: Batch mode sends cloned messages
- **WHEN** batch mode is enabled and the user sends a prompt with checked context items
- **THEN** batch mode no longer exists — this scenario is removed

#### Scenario: Batch mode result collection
- **WHEN** `LLMService.SendToLLM()` returns new messages for a batch item
- **THEN** batch mode no longer exists — this scenario is removed

### Requirement: LLMService.SendToLLM accepts messages and model index directly
**Reason**: While `LLMService.SendToLLM()`'s signature accepting messages and model index directly is still valid and unchanged, the requirement was created in the context of fixing a batch-mode bug. Since batch mode is removed, the rationale for this requirement (avoiding stub session managers) no longer applies. The method signature stays the same — it already takes messages and model index as parameters. No code change to `LLMService.SendToLLM()` itself.

**Migration**: No change to `LLMService.SendToLLM()` — it already accepts messages and model index directly. This requirement is archived as implementation context only.

### Requirement: SendToLLMCommand extracts data before calling the service
**Reason**: `SendToLLMCommand` currently calls `GetMessagesExcludingBatchForSession()` to filter batch messages out of the message list before sending. After batch mode removal, batch-flagged messages will never exist, so the filtering step is replaced with a direct call to `GetSessionMessages()`. The requirement changes: the command no longer needs to exclude batch messages because batch messages don't exist.

**Migration**: Replace `GetMessagesExcludingBatchForSession(targetSessionIndex)` with `GetSessionMessages(targetSessionIndex)` in `SendToLLMCommand.Execute()`.

### Requirement: Batch item labels generated via ContextPresentationService
**Reason**: Batch Mode is unused and being removed entirely. `SendBatchToLLMCommand` and its `ContextPresentationService` dependency for label generation are deleted.

**Migration**: `ContextPresentationService` remains in use by `ContextViewController` — it is not deleted. Only the injection into `SendBatchToLLMCommand` is removed.

#### Scenario: Label generation for file context item
- **WHEN** a batch item is a file path (e.g., `C:\docs\report.txt`)
- **THEN** batch mode no longer exists — this scenario is removed

#### Scenario: Label generation for URL context item
- **WHEN** a batch item is a URL (e.g., `https://example.com`)
- **THEN** batch mode no longer exists — this scenario is removed

#### Scenario: Label generation for plain text context item
- **WHEN** a batch item is plain text (truncated to 50 characters with ellipsis)
- **THEN** batch mode no longer exists — this scenario is removed

#### Scenario: Service dependency injection
- **WHEN** `SendBatchToLLMCommand` is instantiated in `App.ahk`
- **THEN** `SendBatchToLLMCommand` is deleted — this scenario is removed
