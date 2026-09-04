## Context

See proposal.md — Why. Current behavior: only the currently active session is persisted at exit (`ExportSessionState()` → `GetCurrentSession().ToObject()`); sessions 2–5 are recreated blank on start. Exit-save errors are silently swallowed, and writes use `FileDelete` + `FileAppend` (non-atomic).

Relevant existing pieces:
- `Session.ToObject()` / `Session.FromObject()` already round-trip a full session (histories, `historyIndex`, `context`, `llmType`, `systemPrompt`, `processingState`) — no per-session serialization work needed.
- `StateHelper.Save(path, obj)` / `Load(path)` are path-generic; SaveConversationOnExit/LoadConversationOnStart already use them.
- `ImportSessionState(state)` replaces `sessions[currentSessionIndex]` — a single-session operation used by the manual load-from-file feature (`LoadConversationCommand`).
- `MainController.Start()` runs `loadStateOnStartCommand` then `loadConversationOnStartCommand` in a `try/catch` that swallows failures.

## Goals / Non-Goals

**Goals:**
- All 5 sessions survive an open/close cycle, with per-session model, system prompt, histories, and context.
- Correct restore of the active session index.
- Legacy single-session `conversation.json` files still restore (one-time migration).
- No silent persistence failures: writes atomic, exit-save errors logged.
- Architecture-clean: state export/import lives in the service layer; commands do file I/O.

**Non-Goals:**
- Save-on-session-switch or any mid-session incremental persistence (no evidence of crash-loss pattern; exit-save stays the only save point).
- Changing the manual *Save Conversation* / *Load Conversation* feature (`SaveConversationCommand`/`LoadConversationCommand`) — it keeps its current single-session file semantics; loading a new-format all-sessions file through it is not a supported path.
- Changing `state-persistence-collapse` requirements (StateHelper's public Save/Load contract is unchanged).

## Decisions

### Decision: One file, one atomic write — `conversation.json` becomes `{ currentIndex, sessions: [s1..s5] }`

`SaveConversationOnExitCommand` takes `SessionManager.ExportAllSessions()` (a plain object: active index + array of 5 `ToObject()` snapshots) and writes it via `StateHelper.Save`. `LoadConversationOnStartCommand` detects the format and calls `SessionManager.ImportAllSessions(state)`.

Alternatives considered:
- **Five per-session files** (`sessions/session_N.json`): isolated corruption and natural save-on-switch, but more I/O surface, partial-load semantics, and new file-management code — unjustified until a crash-loss pattern exists. Rejected.
- **Keep `conversation.json` as array only**: loses the explicit active index; `currentIndex` inside the wrapper is clearer and matches legacy file shape (`state.json` `sessionIndex` was the old home for this).

Trade-off: the exit write becomes ~5× larger (2.5× the current single-session dump — currently 1.5 MB, so ~5–8 MB). One synchronous write per exit is acceptable; revisit per-session files only if stringify/write time becomes noticeable.

### Decision: `SessionManager` owns whole-state export/import; commands stay thin

- `ExportAllSessions()` → `{ currentIndex: this.currentSessionIndex, sessions: [s1..s5].map(ToObject) }`
- `ImportAllSessions(state)` → rebuilds `this.sessions` from `FromObject`, sets `this.currentSessionIndex` from `state.currentIndex`, and forces each imported session's `processingState` to `ProcessingState.IDLE` (spec: saved mid-request sessions must not come back processing).

Keeps the architecture rule (services own domain state, no file I/O in services). Existing `ExportSessionState`/`ImportSessionState` stay for the manual save/load feature.

### Decision: `state.json` shrinks to `toolOverrides`

`SaveStateOnExitCommand` writes only `toolOverrides`; per-session model/system prompt already serialize inside each session snapshot, so the current-session-only `modelIndex`/`systemPromptIndex`/`sessionIndex` fields become redundant.

`LoadStateOnStartCommand` restores `toolOverrides` only. Since `loadStateOnStartCommand` runs before `loadConversationOnStartCommand`, any stale model/prompt application to the pre-import session is overwritten by the wholesale session import — no ordering hazard.

### Decision: No legacy migration — old-format files yield a fresh start

The previous single-session format is not supported. A `conversation.json` without the all-sessions shape (missing `sessions`/`currentIndex`) fails `ImportAllSessions`, and `MainController.Start()`'s `try/catch` safety net turns that into 5 fresh sessions. No shape detection, no `sessionIndex` readback, no migration code.

Alternatives considered:
- **Shape detection + import into the saved tab**: dropped as scope cut — no real legacy files remain in the wild for this app.
- **Silently ignoring vs. throwing**: `ImportAllSessions` throwing (caught by `Start`) is preferred over returning a flag, keeping the command body minimal and the safety net in one place.

### Decision: Atomic write + reported failures

- **Atomicity in `StateHelper.Save`**: write to `path . ".tmp"`, then `FileMove` over the destination (success replaces, failure leaves the old file intact). Confined to state files; `FileHelper.WriteText` (used for temp/export files elsewhere) is unchanged.
- **Failure reporting**: replace the empty `catch` in `MainController.SaveStateAndConversation` with a catch that writes `"state save failed: <err>"` to `OutputDebug` (visible via DbgView). No dialogs during exit, no persistent log file.

## Risks / Trade-offs

- [Bigger exit write (~5–8 MB)] → One synchronous write per exit; acceptable. If it becomes slow, revisit per-session files (documented alternative, no spec change needed).
- [Legacy files start fresh] → Old-format `conversation.json` present → `ImportAllSessions` throws → `Start()` catch → 5 empty sessions. Deterministic; the old file is never modified or deleted.
- [Rollback of THIS change loses sessions] → Old code cannot parse the new all-sessions format (its `ImportSessionState` throws "Invalid session state file"). Rollback = revert code + delete `conversation.json`/`state.json` (fresh start) or restore a manual single-session export via *Load Conversation*. Documented in migration plan.
- [Silent swallow moves from save to load] → Load failures still yield fresh sessions (spec'd, no dialog); the saved-file remains intact and the failed save is now surfaced via debug output, so the failure is visible.
- [Manual Load Conversation on a new-format file fails] → Non-goal; manual feature keeps its single-session contract.

## Migration Plan

1. Deploy code change (no build step; run `main.ahk`).
2. First start after deploy: no `conversation.json` (or an old-format one, which is ignored) → 5 fresh sessions. First real exit rewrites `conversation.json` in the new all-sessions format.
3. Rollback: revert code, delete `conversation.json` + `state.json` (or load a manual single-session export via *Load Conversation*).

## Open Questions

None blocking. Deferrable: whether the manual *Save Conversation* feature should eventually write the all-sessions format too — unrelated to this change's spec and safe to decide later.