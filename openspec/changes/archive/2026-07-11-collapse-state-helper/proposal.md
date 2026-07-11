## Why

`StateHelper` has four methods: `SaveState`/`LoadState` and `SaveConversation`/`LoadConversation`. Each pair is identical except for the file path — the Save methods share the same serialize-delete-append logic, the Load methods share the same read-parse-try/catch logic. At 44 lines, half the file is pure duplication. Collapsing to a shared `Save(path, obj)` / `Load(path)` pair eliminates the duplication while keeping the named methods as thin wrappers for readability.

## What Changes

- Add `Save(path, obj)` and `Load(path)` as the single implementation of serialization logic
- Refactor `SaveState`/`SaveConversation` to one-line delegates to `Save`
- Refactor `LoadState`/`LoadConversation` to one-line delegates to `Load`
- No caller changes — all 4 Commands continue calling the same named methods

## Capabilities

### New Capabilities
- `state-persistence-collapse`: StateHelper exposes a unified `Save(path, obj)` / `Load(path)` pair — same behavior, less code

### Modified Capabilities
<!-- None — internal refactor, no behavior change -->

## Impact

- **Affected code**: `utils/StateHelper.ahk` only
- **Callers**: Unchanged (`SaveStateOnExitCommand`, `SaveConversationOnExitCommand`, `LoadStateOnStartCommand`, `LoadConversationOnStartCommand`)
- **No breaking changes**
