# dead-code-removal

## Requirements

### Requirement: Application starts without include errors
After dead file removal, the application SHALL start successfully with no `#Include`-related errors.

#### Scenario: Normal startup
- **WHEN** `main.ahk` is executed
- **THEN** the application window appears without any error dialogs

### Requirement: LLM calls function correctly
After removing dead type classes from `Types.ahk`, chat completions SHALL produce correct responses and tool calls.

#### Scenario: Send prompt and receive response
- **WHEN** a user sends a prompt to any configured LLM provider
- **THEN** a response is received and rendered in the WebView

#### Scenario: Tool calls execute correctly
- **WHEN** the LLM returns a tool call (e.g., PowerShell, FileSystem, WebSearch)
- **THEN** the tool executes and returns results

### Requirement: Clipboard copy works
After removing `ClipboardHelper` and inlining its logic, the "Copy to Clipboard" function SHALL place selected message text on the system clipboard.

#### Scenario: Copy message text
- **WHEN** user selects a message in chat history and clicks Copy
- **THEN** the message text is available on the system clipboard

### Requirement: No remaining references to deleted files
No AHK source file in the project SHALL contain a `#Include` referencing a deleted file.

#### Scenario: Verify include integrity
- **WHEN** all changes are applied
- **THEN** every `#Include` path in `App.ahk` and all other `.ahk` files resolves to an existing file
