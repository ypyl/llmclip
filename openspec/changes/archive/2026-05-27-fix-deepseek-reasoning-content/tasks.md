## 1. Parse reasoning_content from API responses

- [x] 1.1 Add `reasoning_content` field check in `OpenAIProvider.ParseResponse()` — after existing `reasoning` check, add: if `message.Has("reasoning_content")`, store in `chatMsg.AdditionalProperties["thinking"]`. Place this AFTER the existing `reasoning` check so `reasoning_content` takes precedence if both are present.

## 2. Serialize thinking as reasoning_content on tool-call requests

- [x] 2.1 Add `HasToolCalls()` helper method to `ChatMessage` class in `Types.ahk` — returns `true` if any `Contents` part is a `FunctionCallContent` instance. Mirrors existing `SessionManager.HasToolCalls()` but as a message-level method.

- [x] 2.2 Modify `ChatMessage.ToObject()` in `Types.ahk` — before the `internalProps` filter loop, add logic: if role is `"assistant"` AND `HasToolCalls()` is true AND `AdditionalProperties["thinking"]` is non-empty, set `obj.reasoning_content := AdditionalProperties["thinking"]`.

## 3. Integration validation

- [x] 3.1 Manual smoke test: launch `main.ahk`, select a `deepseek-v4-flash` model under OpenCodeGo, send a prompt that triggers a tool call (e.g., "read the file at C:\Windows\win.ini"), verify the tool executes and the LLM continues without 400 error. Verify thinking content appears in the message display.

- [x] 3.2 Regression check: verify non-DeepSeek providers (Groq, GitHub, OpenRouter) still work correctly with tool calls. The extra `reasoning_content` field should be silently ignored by these APIs.

- [x] 3.3 Verify thinking content survives: edit a message that has thinking content (remove/add the ```thinking block), confirm the change persists through a save/load conversation cycle.
