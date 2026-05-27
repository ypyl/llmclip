## ADDED Requirements

### Requirement: Parse reasoning_content from API responses

The OpenAI-compatible provider SHALL extract the `reasoning_content` field from assistant messages in API responses and store it in `ChatMessage.AdditionalProperties["thinking"]`.

#### Scenario: DeepSeek returns reasoning_content with tool call

- **WHEN** the API response contains `{"choices":[{"message":{"role":"assistant","content":null,"reasoning_content":"Let me analyze...","tool_calls":[...]}}]}`
- **THEN** the resulting `ChatMessage` SHALL have `AdditionalProperties["thinking"]` set to `"Let me analyze..."`

#### Scenario: DeepSeek returns reasoning_content without tool call

- **WHEN** the API response contains `{"choices":[{"message":{"role":"assistant","content":"The result is...","reasoning_content":"I thought about..."}}]}`
- **THEN** the resulting `ChatMessage` SHALL have `AdditionalProperties["thinking"]` set to `"I thought about..."` AND `Contents` SHALL contain a `TextContent` with `"The result is..."`

#### Scenario: response has no reasoning_content

- **WHEN** the API response contains an assistant message without a `reasoning_content` field
- **THEN** `AdditionalProperties["thinking"]` SHALL remain unset (no key, or empty)

### Requirement: Parse reasoning field from Groq and other providers

The OpenAI-compatible provider SHALL continue to extract the `reasoning` field from assistant messages (used by Groq and others) and store it in `ChatMessage.AdditionalProperties["thinking"]`, normalizing to the same property as `reasoning_content`.

#### Scenario: Groq returns reasoning field

- **WHEN** the API response contains `{"choices":[{"message":{"role":"assistant","reasoning":"Step 1..."}}]}`
- **THEN** the resulting `ChatMessage` SHALL have `AdditionalProperties["thinking"]` set to `"Step 1..."`

#### Scenario: Both reasoning and reasoning_content present

- **WHEN** the API response contains both `reasoning_content` and `reasoning` fields
- **THEN** `reasoning_content` SHALL take precedence (DeepSeek models use this field; the `reasoning` field, if present, may be a subset or duplicate)

### Requirement: Serialize thinking as reasoning_content on tool-call messages

When serializing a `ChatMessage` to a request object via `ToObject()`, if the message has the role `assistant`, contains at least one `FunctionCallContent` (tool call), AND has `AdditionalProperties["thinking"]` set to a non-empty value, the serialized object SHALL include a `reasoning_content` field at the top level (same level as `role` and `content`) with the value from `thinking`.

#### Scenario: Assistant message with tool calls and thinking

- **WHEN** serializing `ChatMessage(role:"assistant", contents:[FunctionCallContent(...)], AdditionalProperties:{"thinking":"Let me analyze..."})`
- **THEN** the output object SHALL be `{"role":"assistant","content":"","tool_calls":[...],"reasoning_content":"Let me analyze..."}`

#### Scenario: Assistant message with tool calls but no thinking

- **WHEN** serializing `ChatMessage(role:"assistant", contents:[FunctionCallContent(...)], AdditionalProperties:{})`
- **THEN** the output object SHALL NOT contain a `reasoning_content` field

#### Scenario: Assistant message with thinking but no tool calls

- **WHEN** serializing `ChatMessage(role:"assistant", contents:[TextContent("Hello")], AdditionalProperties:{"thinking":"Thought process..."})`
- **THEN** the output object SHALL NOT contain a `reasoning_content` field (thinking is only required for tool-call continuations)

#### Scenario: Non-assistant message with thinking

- **WHEN** serializing a `ChatMessage` with `role` other than `"assistant"` that somehow has thinking
- **THEN** the output object SHALL NOT contain a `reasoning_content` field

### Requirement: Display and editing of thinking content preserved

The existing display path (via `MessagePresentationService`) and editing path (via `SessionManager.UpdateMessageText()`) SHALL continue to work with thinking content regardless of whether it originated from `reasoning` or `reasoning_content` parsing.

#### Scenario: Thinking content displayed in WebView

- **WHEN** a `ChatMessage` has `AdditionalProperties["thinking"]` set (from any source)
- **THEN** `MessagePresentationService.GetPresentationText(msg, true)` SHALL wrap the thinking content in a ````thinking` fenced block before the message text

#### Scenario: User edits a message with thinking block

- **WHEN** user edits a message containing ````thinking...```` fence
- **THEN** `SessionManager.UpdateMessageText()` SHALL parse the thinking block out of the visible text and store it in `AdditionalProperties["thinking"]`

### Requirement: Session persistence preserves thinking

The thinking content SHALL survive session export/import (save/load conversation JSON) without changes to the existing serialization format.

#### Scenario: Export and import preserves thinking

- **WHEN** a session containing a message with `AdditionalProperties["thinking"]` is exported to JSON and then imported
- **THEN** the imported message SHALL have the same `AdditionalProperties["thinking"]` value
