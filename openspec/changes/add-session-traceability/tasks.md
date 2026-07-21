## 1. Create TraceabilityService

- [x] 1.1 Create `services/TraceabilityService.ahk` with class that creates `sessions/` directory, opens `yyyy-mm-dd-hh-mm-ss.jsonl` file on construction, and exposes `LogInteraction(sessionIndex, provider, model, requestBody, responseRaw, responseParsed, durationMs, tokens, error)` method
- [x] 1.2 Implement `LogInteraction()` to build a JSON object with keys `ts`, `session`, `provider`, `model`, `request`, `response_raw`, `response_parsed`, `duration_ms`, `tokens` (optional), `error` (optional), serialize via `JSON.Stringify()`, and append as a single line to the open file handle

## 2. Wire into composition root

- [x] 2.1 Add `#Include Services\TraceabilityService.ahk` to `App.ahk` in alphabetical order among other service includes
- [x] 2.2 Instantiate `TraceabilityService` in `App.__New()` and pass it to `LLMClient` constructor as new first parameter
- [x] 2.3 Update `LLMClient.__New(providers, ...)` signature to `LLMClient.__New(traceabilityService, providers)` in `services/LLM/LLMClient.ahk`

## 3. Thread session index to LLMClient

- [x] 3.1 In `LLMService.SendToLLM()`, before calling `this.llmClientInstance.Call()`, add `settings["session_index"]` using the session index from the calling command (pass `sessionIndex` as a new parameter to `SendToLLM`)
- [x] 3.2 Update `SendToLLMCommand.Execute()` to pass `targetSessionIndex` to `this.llmService.SendToLLM()` (it already has this variable in scope)
- [x] 3.3 N/A — `ExecuteToolCallsCommand` calls `LLMService.ExecuteToolCalls()` (local tool execution), not `SendToLLM()`. Tool follow-up goes through `SendToLLMCommand` which already passes `targetSessionIndex` (task 3.2)

## 4. Add logging to LLMClient.Call()

- [x] 4.1 In `LLMClient.Call()`, after receiving `response` and before returning parsed messages, call `this.traceabilityService.LogInteraction()` with all available data (session_index from settings, provider name, model, body Map, raw response string, parsed ChatMessage objects, duration)
- [x] 4.2 Ensure cancelled requests (`Error("Request cancelled")`) are handled before the logging call so they are NOT logged
- [x] 4.3 Ensure error responses (the `catch` block that returns error ChatMessage) ARE logged with the `error` key
- [x] 4.4 Compute `duration_ms` inside `LLMClient.Call()` by capturing `A_TickCount` before and after the curl execution (already partially done in `LLMService`, move timing down)

## 5. Integration verification

- [ ] 5.1 Run `main.ahk`, send a message to LLM, verify `sessions/` directory is created and contains a JSONL file with the expected structure *(manual verification)*
- [ ] 5.2 Trigger a tool call (e.g., ask about a file on disk), verify both round-trips are logged as separate lines *(manual verification)*
- [ ] 5.3 Cancel a request mid-flight, verify no line is written for the cancelled call *(manual verification)*
- [ ] 5.4 Inspect a log line, verify no API key appears in `request` or `response_raw` *(manual verification)*
