## Requirements

### Requirement: User message is built with context and images
`SendToLLMCommand` SHALL construct a user `ChatMessage` from the user's prompt text, any attached images, and selected context items. Context text and images SHALL be attached as `AdditionalProperties` for history rendering.

#### Scenario: Plain text message
- **WHEN** user sends a text prompt with no images and no context
- **THEN** a single `ChatMessage("user", [TextContent(prompt)])` SHALL be appended to session history

#### Scenario: Message with images
- **WHEN** user sends a prompt with one or more images
- **THEN** each image SHALL be added as an `ImageContent` part alongside the `TextContent`
- **AND** the message SHALL have `AdditionalProperties["hasContext"] := true`

#### Scenario: Message with selected context items
- **WHEN** user sends a prompt with checked context items
- **THEN** `ContextManager.BuildPromptContext` SHALL assemble checked item content into a `<CONTEXT>` block
- **AND** the context block SHALL be prepended to the message as the first `TextContent`
- **AND** `AdditionalProperties["hasTextContext"]` SHALL be set to `true`

#### Scenario: Empty prompt is sent
- **WHEN** user sends with an empty prompt but has context or images
- **THEN** the message SHALL still be constructed and sent (no text content, only context/images)

### Requirement: System prompt is refreshed before sending
Before each LLM call, `SendToLLMCommand` SHALL read the current system prompt value from `ConfigurationService` and update the session's system message content.

#### Scenario: System prompt updated before send
- **WHEN** `SendToLLMCommand.Execute` is called
- **THEN** the system message in session history SHALL reflect the currently selected system prompt
- **AND** the prompt is indexed by `(modelIndex, systemPromptIndex)`

### Requirement: Tool enablement is read per-model before sending
`SendToLLMCommand` SHALL check each tool's enabled state via `ConfigurationService.IsToolEnabled(modelIndex, toolName)` for all six tools, respecting per-model overrides.

#### Scenario: Tools enabled per model defaults
- **WHEN** a model's `providers.json` entry includes `"tools": ["execute_powershell", "web_search"]`
- **THEN** those tools SHALL be enabled for the LLM call
- **AND** tools not listed SHALL be disabled

#### Scenario: Tool override overrides default
- **WHEN** user previously toggled `"web_search"` off for the current model
- **THEN** `IsToolEnabled` returns `false` regardless of the provider default

### Requirement: LLM response is appended to session history
After receiving a response from `LLMService.SendToLLM`, all new messages (assistant text and/or tool calls) SHALL be appended to the target session's message history.

#### Scenario: Assistant text response
- **WHEN** LLM returns a single assistant message with text content
- **THEN** the `ChatMessage("assistant", ...)` SHALL be appended to session messages

#### Scenario: Assistant returns tool calls
- **WHEN** LLM returns an assistant message containing `FunctionCallContent` entries
- **THEN** the command SHALL return `{action: "tool_pending", hasUnexecutedToolCalls: true}`
- **AND** the calling controller SHALL trigger tool execution

#### Scenario: Request cancelled
- **WHEN** the user cancels the LLM request mid-flight
- **THEN** the command SHALL return `{action: "idle"}` without throwing

### Requirement: Regeneration branches message history
When `isRegeneration` is `true`, `SendToLLMCommand` SHALL NOT append a new user message and SHALL instead send the existing conversation history to the LLM, allowing the assistant's last response to be replaced.

#### Scenario: Regeneration sends existing history
- **WHEN** `Execute` is called with `isRegeneration := true`
- **THEN** no new user message SHALL be added to session history
- **AND** the existing messages (including the last user message) SHALL be sent to the LLM
