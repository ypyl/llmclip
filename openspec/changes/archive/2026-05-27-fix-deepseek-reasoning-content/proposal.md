## Why

DeepSeek models (`deepseek-v4-flash`, `deepseek-v4-pro`) in thinking mode return a `reasoning_content` field alongside assistant messages. When a tool call occurs, this field **must** be echoed back in subsequent API requests — without it, the API returns HTTP 400. LLMClip neither captures `reasoning_content` from responses nor includes it in follow-up requests, breaking all tool-call workflows with these models.

## What Changes

- **Parse `reasoning_content`** from API responses (OpenAIProvider), normalizing it into the existing `thinking` property on `ChatMessage`
- **Serialize `thinking` back to the API** when an assistant message has tool calls (currently stripped as internal metadata)
- **Emit `reasoning_content` as a message-level field** at the same level as `role` and `content` in the request JSON (matching the DeepSeek API contract)
- **Handle both field name variants** (`reasoning` from Groq, `reasoning_content` from DeepSeek) during parsing to cover all reasoning models

## Capabilities

### New Capabilities

- `reasoning-content-roundtrip`: Capture reasoning/thinking content from LLM responses, preserve it through the conversation lifecycle (including tool-call continuations, message editing, and session import/export), and serialize it back to the API when required.

### Modified Capabilities

<!-- None — existing spec requirements are unchanged -->

## Impact

- **Affected code**: `OpenAIProvider.ahk` (parsing + serialization), `ChatMessage.ToObject()` in `Types.ahk` (serialization), `LLMClient.ahk` (indirect — receives correctly serialized requests)
- **Affected models**: `deepseek-v4-flash`, `deepseek-v4-pro` (OpenCodeGo provider). Potentially benefits other reasoning models (Groq compound, Ollama thinking variants) by improving `thinking` roundtrip fidelity, though these don't strictly require it.
- **No breaking changes**: The fix adds fields to outgoing requests that most OpenAI-compatible APIs either require (DeepSeek) or safely ignore. The existing `thinking` display and editing flows are unchanged.
- **No new dependencies**: Pure bugfix within existing provider and type layers.
