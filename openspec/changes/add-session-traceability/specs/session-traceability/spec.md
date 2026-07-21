## ADDED Requirements

### Requirement: Traceability service manages session log files

The system SHALL provide a `TraceabilityService` that creates a `sessions/` directory relative to the executable and sets the file path for a new JSONL file named `<yyyy-mm-dd-hh-mm-ss>.jsonl` when the app starts. Each log entry is written via `FileAppend`, which opens the file, writes, and closes it immediately — ensuring data is flushed to disk without requiring a long-lived file handle.

#### Scenario: App start sets log file path

- **WHEN** `TraceabilityService.__New()` is called
- **THEN** a `sessions/` directory is created if it does not exist
- **AND** the file path is set to `sessions/yyyy-mm-dd-hh-mm-ss.jsonl` (using the current local time at construction)

#### Scenario: Concurrent app instances get separate files

- **WHEN** two instances of the app start within the same second
- **THEN** each instance writes to the same file (filename collision at same-second resolution — timestamps in lines distinguish entries)

### Requirement: LLM API calls are logged as JSONL lines

The system SHALL append one JSON object per line to the session JSONL file for each `LLMClient.Call()` invocation, containing the timestamp, internal session index, provider name, model identifier, request metadata (without the full message history to avoid duplication), the raw API response string, parsed response messages, call duration in milliseconds, and token usage when available.

#### Scenario: Successful API call is logged

- **WHEN** `LLMClient.Call()` completes successfully
- **THEN** a single JSON line is appended to the current session JSONL file
- **AND** the line contains keys: `ts`, `session`, `provider`, `model`, `request`, `response_raw`, `response_parsed`, `duration_ms`
- **AND** `request` contains API metadata (model, temperature, tools, etc.) but NOT the full `messages` array
- **AND** `request.message_count` is the number of messages in the full conversation context
- **AND** `request.prompt` is only the last message in the request (the new user message or tool result that triggered the call)
- **AND** `response_parsed` is an array of message objects (as returned by the provider's `ParseResponse`)
- **AND** if the API response includes token usage, it is included as a `tokens` key

#### Scenario: Failed API call is logged

- **WHEN** `LLMClient.Call()` throws an error (non-cancellation)
- **THEN** a JSON line is still appended if the request was sent
- **AND** the line includes an `error` key with the error message
- **AND** `response_raw` contains whatever partial response was received (empty string if none)

#### Scenario: Cancelled request is not logged

- **WHEN** `LLMClient.Call()` is cancelled mid-flight (user presses cancel)
- **THEN** no JSONL line is appended (the interaction produced no meaningful result)

### Requirement: Each tool-call round-trip is logged separately

The system SHALL log each `LLMClient.Call()` as a separate JSONL line, including calls made to resolve tool calls.

#### Scenario: Tool call chain produces multiple lines

- **WHEN** a user message triggers an assistant response with tool calls, followed by tool results sent back, followed by a final assistant response
- **THEN** the JSONL file contains one line for the initial assistant response (with tool calls)
- **AND** one line for the subsequent call that includes tool results and produces the final response
- **AND** both lines share the same `session` value

### Requirement: API keys are never written to the log

The system SHALL NOT write API keys to the JSONL file. The logged `request` body is the JSON payload sent to the API, which uses HTTP headers for authentication.

#### Scenario: API key absent from logged request

- **WHEN** an LLM call is made with any provider (OpenAI, Google, Ollama, Groq)
- **THEN** the `request` field in the JSONL line does not contain the API key value
- **AND** the `response_raw` field does not contain the API key value

### Requirement: New service follows architectural layer rules

The `TraceabilityService` SHALL be a Service in the `services/` directory, owning a file path string and performing writes via `FileAppend` (which opens, writes, and closes the file on each call). It SHALL NOT reference any View, Controller, or Command.

#### Scenario: Service instantiation in composition root

- **WHEN** the app starts
- **THEN** `TraceabilityService` is instantiated in `App.ahk`
- **AND** its `#Include` is added to `App.ahk`
- **AND** it is passed to `LLMClient` via constructor injection

#### Scenario: Service has no UI dependencies

- **WHEN** `TraceabilityService` is inspected
- **THEN** it contains no references to `ui/`, `controllers/`, or `commands/`
- **AND** it only uses `#Include` for `Lib\Json.ahk` (for JSON serialization) and possibly `Utils\FileHelper.ahk`
