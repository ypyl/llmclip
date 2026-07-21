## Why

Currently there is no durable record of what gets sent to and received from LLM APIs. The raw request/response exists only as ephemeral temp files (`temp/request.json`, `temp/response.json`) that get overwritten on every call. When debugging prompt quality, tracking token usage over time, or auditing model behavior, there's no way to look back at what actually happened. This adds an append-only, JSONL-based audit log of every LLM interaction.

## What Changes

- Add a `TraceabilityService` that creates and manages a `sessions/` folder next to the executable
- On app start, open a new `.jsonl` file named with the current timestamp (`yyyy-mm-dd-hh-mm-ss.jsonl`)
- Log every LLM API round-trip (including tool call chains) as a separate JSONL line
- Each line captures: timestamp, internal session index, provider, model, request body (structured), raw response, duration, and token usage
- API keys are never logged (they live in HTTP headers, not the request body being logged)
- No file cleanup or rotation (YAGNI)

## Capabilities

### New Capabilities
- `session-traceability`: Append-only JSONL logging of every LLM API call for auditing and debugging

### Modified Capabilities
<!-- None - this is purely additive, no existing behavior changes -->

## Impact

- **New file**: `services/TraceabilityService.ahk` — owns JSONL file handle, exposes `LogInteraction()` method
- **Modified**: `services/LLM/LLMClient.ahk` — receives `TraceabilityService` via constructor, logs each call in `Call()`
- **Modified**: `services/LLM/LLMService.ahk` — threads `session_index` into the `settings` Map so `LLMClient` can log it
- **Modified**: `App.ahk` — instantiate `TraceabilityService`, add `#Include`, wire into `LLMClient` constructor
- **New directory**: `sessions/` (gitignored) next to executable at runtime
