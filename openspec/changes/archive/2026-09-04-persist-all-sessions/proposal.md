## Why

On real exit, only the currently-active session is ever written to disk: `SaveConversationOnExitCommand` calls `ExportSessionState()`, which serializes `GetCurrentSession().ToObject()` alone. Sessions 2–5 are recreated blank on every start, so after an open/close cycle at most one session has content — and which one depends on which tab was active at exit, which reads as "randomly some sessions restored, some not". On top of that, save failures are silently swallowed (`catch {}` in `SaveStateAndConversation`) and writes are non-atomic (`FileDelete` → `FileAppend`), so restores can also intermittently come back stale (wrong session index vs. old conversation file) or empty (truncated file → load returns `""`).

All 5 sessions should survive an app restart, with their messages, context, model, and system prompt intact.

## What Changes

- **BREAKING** `conversation.json` format: becomes `{ "currentIndex": N, "sessions": [session1..session5] }` containing the full state of all 5 sessions (histories, history index, context, model, system prompt).
- `SessionManager` gains whole-state export/import: `ExportAllSessions()` and `ImportAllSessions(state)`. Import replaces all 5 session objects and restores the active session index.
- `SaveConversationOnExitCommand` writes the all-sessions object; `LoadConversationOnStartCommand` imports it.
- `state.json` shrinks to `toolOverrides` only. Per-session model and system prompt already serialize inside each session snapshot (`llmType`, `systemPrompt`), so the current-session-only `modelIndex`/`systemPromptIndex`/`sessionIndex` fields become redundant and are removed from writes and reads.
- **Migration**: none. Old-format (single-session) `conversation.json` files are not migrated — a file without the all-sessions shape is ignored and the app starts with 5 fresh sessions.
- **Reliability**: restored sessions force `processingState` to IDLE (a session closed mid-request must not come back "processing"). State writes become atomic (tmp file + rename). Exit-save failures are surfaced via debug output instead of silently swallowed.
- No change to per-session save-on-switch: persistence happens on real exit only, matching current behavior.

## Capabilities

### New Capabilities

- `session-persistence`: All 5 sessions are saved on exit and fully restored on start, including the active session index, per-session model and system prompt, history branches, and context. Covers the `conversation.json` file format and the reliability guarantees around writes. Only the current all-sessions format is supported; old-format state files are ignored.

### Modified Capabilities

- None. The existing `state-persistence-collapse` spec (StateHelper unified save/load) keeps its observable requirements: save replaces the existing file, load of a missing/corrupt file returns `""`. Atomic write and error logging are implementation details of the new `session-persistence` capability, not changes to those requirements.

## Impact

- `Services/SessionManager.ahk` — add `ExportAllSessions` / `ImportAllSessions`; session-index selection becomes part of import.
- `Services/Session.ahk` — no structural change needed (`ToObject`/`FromObject` already round-trip per-session state); verify `processingState` handling on restore.
- `Commands/SaveConversationOnExitCommand.ahk`, `Commands/LoadConversationOnStartCommand.ahk` — switch to whole-state export/import; no old-format handling.
- `Commands/SaveStateOnExitCommand.ahk`, `Commands/LoadStateOnStartCommand.ahk` — narrow to `toolOverrides` only.
- `Utils/StateHelper.ahk` / `Utils/FileHelper.ahk` — atomic write helper; load of legacy format remains tolerant.
- `Controllers/MainController.ahk` — `SaveStateAndConversation` reports failures instead of swallowing.
- Disk artifacts: `conversation.json` (new format), `state.json` (reduced).