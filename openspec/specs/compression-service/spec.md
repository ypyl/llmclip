# compression-service

Compression LLM operations accept pre-extracted messages, conversation text, and model index directly rather than depending on a `SessionManager` interface. Commands own data extraction; the service owns prompt building, validation, and LLM invocation.

## Requirements

### Requirement: Compression service accepts pre-extracted data
`LLMService.CompressHistory()` SHALL accept a messages array, a conversation text string, and a model index integer instead of a `SessionManager` instance and session index.

#### Scenario: Compression with valid inputs
- **WHEN** a command calls `CompressHistory(messages, conversationText, modelIndex)` with at least 3 messages, non-empty conversation text, and a valid model index
- **THEN** the service fetches the compression prompt from configuration using the model index
- **THEN** the service appends the conversation text to the compression prompt
- **THEN** the service builds temporary messages with the system message and compression request
- **THEN** the service calls the LLM with no tools enabled and returns the compressed message

#### Scenario: Compression with insufficient messages
- **WHEN** `CompressHistory(messages, ...)` is called with fewer than 3 messages
- **THEN** the service throws an error indicating insufficient messages

#### Scenario: Compression with empty conversation text
- **WHEN** `CompressHistory(messages, conversationText, ...)` is called with empty conversation text
- **THEN** the service throws an error indicating no conversation to compress

### Requirement: Compression command passes extracted data to service
`CompressHistoryCommand.Execute()` SHALL extract messages, conversation text, and model index from the session manager, pass them to `LLMService.CompressHistory()`, and mutate session state with the result.

#### Scenario: Successful compression flow
- **WHEN** `CompressHistoryCommand.Execute()` is called
- **THEN** the command extracts messages via `GetSessionMessages()`, conversation text via `FormatMessagesForCompressionForSession()`, and model index via `GetSessionModelIndex()`
- **THEN** the command calls `LLMService.CompressHistory(messages, conversationText, modelIndex)`
- **THEN** the command does NOT duplicate validation or prompt-building logic that exists in the service
- **THEN** if a compressed message is returned, the command replaces the session history with it via `ReplaceWithCompressedForSession()`
