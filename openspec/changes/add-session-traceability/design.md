## Context

LLMClip currently writes every LLM request to `temp/request.json` and every response to `temp/response.json` inside `LLMClient.Call()`. These are ephemeral — overwritten on each call, and the `temp/` folder may be cleaned by the OS. There is no persistent audit trail of LLM interactions.

The conversation state is persisted separately via `SaveConversationCommand` (the internal `ChatMessage[]` structures serialized as JSON), but this is the *logical* state for restoration — not a raw record of what was sent to the API.

External LLM debugging tools and platforms (LangSmith, Phoenix, etc.) all use append-only, structured logging. JSONL is the standard interchange format: one JSON object per line, append-friendly, trivially queryable with `grep`, `jq`, or DuckDB.

## Goals / Non-Goals

**Goals:**
- Persist every LLM API round-trip (request + response) to a durable, append-only JSONL file
- One file per app runtime session, named by launch timestamp
- One JSONL line per `LLMClient.Call()` invocation (including tool-call chains)
- Zero leakage of API keys
- Minimal architectural disruption — log at the single choke point all LLM traffic passes through

**Non-Goals:**
- File rotation or cleanup (YAGNI)
- A UI for browsing/logs (plain files, use external tools)
- Logging tool execution results (only LLM API calls)
- Logging streaming chunks (only complete request/response pairs)
- Replacing existing conversation save/load

## Decisions

### Decision 1: Log inside `LLMClient.Call()`, not higher

**Chosen**: `LLMClient.Call()` is where the raw request body (Map) and raw response (string) both exist. This is the single choke point for all LLM API traffic.

**Alternatives considered**:
- `LLMService.SendToLLM()`: Has session context and timing, but only sees structured ChatMessage objects — misses the raw API payloads.
- `SendToLLMCommand.Execute()`: Farthest from the data; would require threading raw payloads back up.

**Trade-off**: `LLMClient` doesn't know about session indices. Solution: thread `session_index` through the existing `settings` Map (Decision 2).

### Decision 2: Thread `session_index` via `settings` Map

**Chosen**: `LLMService.SendToLLM()` already receives the target session's messages and model index. Before calling `llmClient.Call()`, it adds `settings["session_index"]` with the session index. `LLMClient` reads it for logging purposes only.

This avoids a signature change on `Call()` and keeps `LLMClient` unaware of `SessionManager`.

**Why not pass it as a parameter?** The `settings` Map already carries call-specific metadata (model, tools, temperature, provider). Session index is the same category — contextual metadata, not core logic.

### Decision 3: `TraceabilityService` is a Service, not a Utils class

**Chosen**: Service. It owns state (the open file handle), performs OS operations (directory creation, file I/O), and has no UI/controller/command dependency.

**Why not Utils?** Utils are stateless static helpers. A file that stays open across calls requires state. Per architectural rules, Services own domain state and persistence.

### Decision 4: Log raw response string, structured request body

**Chosen**: 
- `request`: The structured Map (as-sent JSON body). Provider-independent, already available as `body` variable.
- `response_raw`: The untouched API response string. Ground truth for debugging provider quirks or parsing bugs.
- `response_parsed`: The parsed ChatMessage objects from `ParseResponse()`.

This gives both the wire-level truth and the structured interpretation.

### Decision 5: No API key redaction needed

**Rationale**: In the OpenAI-compatible API pattern, the API key is an HTTP header (`Authorization: Bearer <key>`), not part of the JSON body. The `body` Map logged as `request` never contains the key. The raw response is the JSON body returned by the API — APIs don't echo back the key. Verified by inspecting `OpenAIProvider.GetRequestBody()` and the curl templates in `providers.json`.

### Decision 6: One file per app launch, not per internal session

**Chosen**: File named `yyyy-mm-dd-hh-mm-ss.jsonl` created in `TraceabilityService.__New()`. All 5 internal sessions write to this same file. The `session` field in each line disambiguates.

**Why not per-internal-session?** Internal sessions persist across app restarts. A single internal session could span multiple files (one per app launch), which is fine — the `session` field + timestamp line provides the correlation. Starting a new file each launch is simpler and matches the user's stated intent.

## Risks / Trade-offs

- **Disk growth**: JSONL files accumulate without bound. Mitigation: YAGNI — users can delete old files manually. A rotation mechanism can be added later if needed.
- **Crash during write**: If the app crashes mid-write, a line could be truncated. Mitigation: JSONL is line-delimited; a truncated last line is easily ignored by parsers. Each line is a single `FileAppend` call.
- **Concurrent access**: Only one `Call()` runs at a time (synchronous curl subprocess). No concurrent write risk.
- **Sensitive data in responses**: LLM responses could contain user data from the conversation. The `sessions/` folder should be treated as sensitive — users should be aware these files exist. The folder is not gitignored by the app itself, but users can add it to `.gitignore`.
