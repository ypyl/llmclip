## Context

LLMClip uses OpenAI-compatible providers to call LLM APIs. Responses are parsed by provider-specific `ParseResponse()` methods, which build `ChatMessage` instances. These messages are later serialized back to JSON by `ChatMessage.ToObject()` when constructing follow-up API requests.

DeepSeek's thinking mode introduces a `reasoning_content` field at the message level (alongside `role`, `content`, `tool_calls`) that captures the model's chain-of-thought. When a tool call occurs, DeepSeek **requires** this field to be echoed back in the next request. Currently LLMClip has two gaps:

1. **Parse gap**: `OpenAIProvider.ParseResponse()` checks for `reasoning` but not `reasoning_content`
2. **Serialize gap**: `ChatMessage.ToObject()` classifies `thinking` as internal metadata and strips it from API requests

This is a pure bugfix within the Services layer — no new files, no architectural changes, no new dependencies.

## Goals / Non-Goals

**Goals:**
- Capture `reasoning_content` from DeepSeek API responses
- Include it as `reasoning_content` in follow-up requests when the message has tool calls
- Maintain backward compatibility with existing `reasoning`-based providers (Groq)
- Keep all existing thinking display/editing/persistence flows untouched

**Non-Goals:**
- Changing how thinking is displayed or edited in the UI
- Adding provider-level configuration for thinking mode (e.g., toggling `reasoning_effort`)
- Adding streaming support for reasoning_content chunks
- Changing the Ollama provider (already handles `thinking` correctly)
- Adding DeepSeek as a new named provider type (stays under OpenCodeGo → OpenAI-compatible routing)

## Decisions

### Decision 1: Parse both `reasoning` and `reasoning_content`, normalize to `thinking`

**Choice**: Add a `reasoning_content` check in `OpenAIProvider.ParseResponse()` alongside the existing `reasoning` check. Both store into `AdditionalProperties["thinking"]`. If both fields are present, `reasoning_content` takes precedence.

**Rationale**: The existing codebase already uses `AdditionalProperties["thinking"]` as the canonical storage for reasoning/thinking content across all providers (Ollama stores `thinking` here, OpenAIProvider stores `reasoning` here). Adding `reasoning_content` to the same property avoids duplicating display, editing, and persistence logic.

**Alternatives considered**:
- Storing under a different key (`reasoningContent`) → would require changes to display, editing, and persistence code for no benefit
- Not normalizing (storing raw field name) → adds complexity when multiple field names mean the same thing

### Decision 2: Emit `reasoning_content` as the serialized field name

**Choice**: When serializing an assistant message with tool calls and thinking, emit `"reasoning_content": "<value>"` at the top level of the message object.

**Rationale**: DeepSeek is the provider that **requires** this field, and DeepSeek uses `reasoning_content`. Other OpenAI-compatible providers (Groq, GitHub, OpenRouter) that don't require it will ignore the extra field — OpenAI-compatible APIs are documented to ignore unknown fields.

**Alternatives considered**:
- Emitting `reasoning` instead → would satisfy Groq's format but fail for DeepSeek (which expects `reasoning_content`)
- Making field name provider-configurable → overengineered for a single customer (DeepSeek). If other providers diverge in the future, this can be revisited.
- Emitting both `reasoning` and `reasoning_content` → redundant, bloats request size

### Decision 3: Only emit on messages with tool calls

**Choice**: `ToObject()` includes `reasoning_content` only when ALL of these are true:
1. Message role is `"assistant"`
2. Message has at least one `FunctionCallContent`
3. `AdditionalProperties["thinking"]` is non-empty

**Rationale**: DeepSeek's documentation explicitly states that `reasoning_content` is only required after tool calls. For regular assistant messages (final answers), it's unnecessary. Sending it only when needed keeps request payloads clean and avoids potential confusion for other providers.

**Alternatives considered**:
- Always emitting when thinking exists → safe but unnecessary. Could confuse non-DeepSeek providers that don't expect it on non-tool-call messages.
- Provider-level flag to control emission → overengineered for the current scope.

### Decision 4: Modify `ToObject()` directly (not post-process in provider)

**Choice**: The serialization logic lives in `ChatMessage.ToObject()`, not in `OpenAIProvider.AdaptMessages()`.

**Rationale**: `ToObject()` already handles all content-to-JSON serialization for every message type (text, images, tool calls, tool results). Adding `reasoning_content` here keeps all serialization logic in one place. The field is part of the message's API representation, so it belongs at the message level.

**Alternatives considered**:
- Post-processing in `AdaptMessages()` → would require the provider to check each message's `AdditionalProperties` and inject fields. Duplicates concern that `ToObject()` is already responsible for.
- Provider-level serialization override → would mean duplicating all of `ToObject()`'s logic in each provider. Fragile and verbose.

### Decision 5: No changes to the `internalProps` list

**Choice**: `"thinking"` remains in the `internalProps` blocklist. The new code adds an **explicit check** before the blocklist filter that emits `reasoning_content` when the message has tool calls.

**Rationale**: Removing `"thinking"` from `internalProps` would cause it to be serialized on ALL messages (not just tool-call ones), potentially confusing other providers. The explicit check is more targeted and self-documenting.

## Implementation Approach

Two targeted changes, no new files:

```
┌─────────────────────────────────────────────────────────────┐
│  Change 1: OpenAIProvider.ParseResponse()                   │
│                                                             │
│  After existing "reasoning" check, add:                     │
│                                                             │
│  if (message.Has("reasoning_content")) {                    │
│      chatMsg.AdditionalProperties["thinking"]               │
│        := message["reasoning_content"]                      │
│  }                                                          │
│                                                             │
│  (If both "reasoning" and "reasoning_content" exist,        │
│   the latter overwrites — reasoning_content is the          │
│   authoritative field for DeepSeek)                         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Change 2: ChatMessage.ToObject()                           │
│                                                             │
│  Before the internalProps filter loop, add:                 │
│                                                             │
│  ; Include reasoning_content for tool-call continuations    │
│  if (this.Role == "assistant"                               │
│      && this.HasToolCalls()                                 │
│      && this.AdditionalProperties.Has("thinking")           │
│      && this.AdditionalProperties["thinking"] != "") {      │
│      obj.reasoning_content :=                               │
│        this.AdditionalProperties["thinking"]                │
│  }                                                          │
│                                                             │
│  Where HasToolCalls() checks if any content part            │
│  is a FunctionCallContent instance.                         │
└─────────────────────────────────────────────────────────────┘
```

No changes needed in:
- `App.ahk` (no new classes)
- `LLMClient.ahk` (transparent — receives correctly serialized request)
- `SessionManager` (thinking already stored in AdditionalProperties)
- `MessagePresentationService` (already renders thinking)
- `OllamaProvider` (already handles `thinking` correctly)
- `Session` import/export (AdditionalProperties already serialized)

## Risks / Trade-offs

- **[Risk] Unknown field rejection by non-DeepSeek providers**: If a provider rejects requests with unrecognized `reasoning_content` fields. → **Mitigation**: The field is only emitted on tool-call messages with thinking, and OpenAI-compatible APIs are documented to ignore unknown fields. DeepSeek is the only provider known to both require and return this field.
- **[Risk] `reasoning_content` takes precedence over `reasoning`**: If a future provider returns both fields with different content, the `reasoning` value is lost. → **Mitigation**: No known provider returns both fields simultaneously. If this changes, the precedence can be adjusted.
- **[Trade-off] Memory**: Thinking content is stored in `AdditionalProperties` on every message, increasing memory for large conversations. → Acceptable — thinking content is typically short (a few paragraphs) and was already being stored for display purposes.

## Open Questions

- **Is `reasoning_content` ever streamed chunk-by-chunk?** Not relevant currently (no streaming support). If streaming is added later, the parser would need to accumulate `reasoning_content` across chunks.
- **Do other OpenCodeGo models (qwen3.6-plus) also return `reasoning_content`?** Unknown — the fix handles it generically, so it would work if they do.
