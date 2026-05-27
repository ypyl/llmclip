# batch-mode

Batch mode sends a prompt against multiple checked context items, cloning the message history per item and collecting individual responses.

## Requirements

### Requirement: Batch mode sends messages without a stub session manager
When batch mode is active, the system SHALL construct LLM requests by passing the cloned message array and model index directly to `LLMService.SendToLLM()`, without constructing a synthetic session manager stub object.

#### Scenario: Batch mode sends cloned messages
- **WHEN** batch mode is enabled and the user sends a prompt with checked context items
- **THEN** `SendBatchToLLMCommand` clones the base message history per batch item, adds item-specific context, and calls `SendToLLM(clonedMessages, modelIndex, ...)` directly
- **THEN** no stub object mimicking `SessionManager` is constructed

#### Scenario: Batch mode result collection
- **WHEN** `LLMService.SendToLLM()` returns new messages for a batch item
- **THEN** those messages are tagged with `isBatchResponse` and `batchContextItem` properties and appended to the real session's history
- **THEN** the batch update callback is invoked with the item label and new messages

### Requirement: LLMService.SendToLLM accepts messages and model index directly
`LLMService.SendToLLM()` SHALL accept a messages array and a model index integer instead of a `SessionManager` instance and session index.

#### Scenario: Normal send with extracted data
- **WHEN** a command calls `SendToLLM(messages, modelIndex, answerSize, ...)`
- **THEN** the service uses the provided `messages` array for the LLM request
- **THEN** the service uses the provided `modelIndex` to determine provider settings
- **THEN** the service does not call any method on a session manager object

#### Scenario: Date/time appended to system message
- **WHEN** `SendToLLM` receives a messages array where the first message has role "system"
- **THEN** the current date and time is appended to that system message's text content
- **THEN** the mutation affects the caller's ChatMessage instance (same object reference)

#### Scenario: Answer size instruction temporary message
- **WHEN** answer size is "Small" or "Long"
- **THEN** a temporary user message with the answer size instruction is pushed to the messages array before the LLM call and removed after
- **THEN** the temporary message is never persisted to session history

### Requirement: SendToLLMCommand extracts data before calling the service
`SendToLLMCommand.Execute()` SHALL extract the filtered messages and model index from the session manager before calling `LLMService.SendToLLM()`, rather than passing the session manager to the service.

#### Scenario: Normal message send flow
- **WHEN** `SendToLLMCommand.Execute()` is called with a prompt and optional images
- **THEN** the command builds the user message content and context
- **THEN** the command extracts `GetMessagesExcludingBatchForSession(targetSessionIndex)` and `GetSessionModelIndex(targetSessionIndex)` from the session manager
- **THEN** the command calls `LLMService.SendToLLM(messages, modelIndex, ...)` with the extracted values
- **THEN** the command adds returned messages to the session and returns the processing state result

#### Scenario: Regeneration flow
- **WHEN** `SendToLLMCommand.Execute()` is called with `isRegeneration = true`
- **THEN** the command skips building a new user message
- **THEN** the command still extracts messages and model index from the session before calling the service
