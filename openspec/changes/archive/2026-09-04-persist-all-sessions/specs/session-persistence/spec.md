## ADDED Requirements

### Requirement: All sessions are saved on exit

On real app exit, the complete state of all 5 sessions is written to `conversation.json`, together with the index of the session that was active at exit.

The per-session state includes: message histories (including history branches and the active branch index), context items, the session's model selection, the session's system prompt selection, and the session's processing state.

#### Scenario: Saving on exit preserves all 5 sessions

- **WHEN** the application exits
- **THEN** `conversation.json` contains the full state of all 5 sessions and the index of the active session

#### Scenario: Saving on exit preserves the active session index

- **WHEN** the application exits while session N is active
- **THEN** the saved state records N as the active session, and no other tab is recorded as active

### Requirement: All sessions are restored on start

On application start, if a valid saved state exists, all 5 sessions are reconstructed from it — messages, context, model, system prompt, and history branches included — and the saved active session index becomes the active session.

A restored session that was saved mid-request starts in the idle state, never in a processing state.

#### Scenario: Restoring all sessions after a save

- **WHEN** the application starts and `conversation.json` contains a valid all-sessions state
- **THEN** all 5 sessions contain the messages and context they had at exit, each session keeps its own model and system prompt selection, and the tab that was active at exit is active again

#### Scenario: Restoring a session that was saved mid-request

- **WHEN** a saved session's processing state is not idle
- **THEN** the session starts in the idle state on restore

#### Scenario: Missing, corrupt, or old-format saved state

- **WHEN** `conversation.json` is missing, contains invalid JSON, or contains a single-session object rather than an all-sessions object
- **THEN** the application starts with 5 fresh sessions and no error dialog is shown

### Requirement: Only the all-sessions format is supported

The previous single-session conversation file format is not migrated or read. A state file without the all-sessions shape is treated as no saved state.

#### Scenario: Old-format file is ignored

- **WHEN** `conversation.json` contains a single session object under `histories` rather than a `sessions` array
- **THEN** the application starts with 5 fresh sessions

### Requirement: Per-session model and system prompt restore with session state

The model and system prompt of every session are restored from that session's own saved state, not from a single global value. Session-scoped UI state that depends on the active session follows the restored active session.

#### Scenario: Two sessions with different models survive a restart

- **WHEN** the application exits with session A on model X and session B on model Y
- **THEN** after restart session A has model X and session B has model Y

### Requirement: Persistence writes are atomic and failures are surfaced

State file writes are atomic: a write interrupted by process termination cannot leave a truncated or partial JSON file, and save failures on exit are surfaced rather than silently ignored.

#### Scenario: Interrupted write never corrupts the saved state

- **WHEN** a state write is interrupted before completion
- **THEN** the previously saved file remains intact and loadable

#### Scenario: Failed exit save is surfaced

- **WHEN** writing state on exit fails
- **THEN** the failure is surfaced via debug output rather than silently swallowed, and no error dialog is shown