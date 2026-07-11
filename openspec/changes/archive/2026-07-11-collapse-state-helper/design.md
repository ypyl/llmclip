## Context

`utils/StateHelper.ahk` currently has four static methods: `SaveState`, `LoadState`, `SaveConversation`, `LoadConversation`. The two save methods share identical logic (JSON.Stringify → FileDelete → FileAppend) differing only in the file path (state.json vs conversation.json). The two load methods share identical logic (FileExist check → FileRead → JSON.Load with try/catch), again differing only by path. This is pure copy-paste duplication.

All four methods are called by exactly one Command each (`SaveStateOnExitCommand`, `SaveConversationOnExitCommand`, `LoadStateOnStartCommand`, `LoadConversationOnStartCommand`).

## Goals / Non-Goals

**Goals:**
- Remove the duplicated save/load logic
- Keep backward compatibility: existing callers unchanged
- Reduce StateHelper from ~44 lines to ~28 lines

**Non-Goals:**
- No caller changes
- No path configuration changes
- No changes to state.json or conversation.json format

## Decisions

**Decision: Extract `Save(path, obj)` and `Load(path)` as private implementation, keep named wrappers.**

The existing `SaveState(stateObj)` becomes `Save(statePath, stateObj)`. The named methods become one-liners:
```
static SaveState(stateObj) => StateHelper.Save(StateHelper.GetStatePath(), stateObj)
static LoadState() => StateHelper.Load(StateHelper.GetStatePath())
```

Alternative considered: Replace callers directly to call `Save(StateHelper.GetStatePath(), obj)`. Rejected — the named methods serve as documentation; the callers benefit from `StateHelper.SaveState(obj)` over raw path passing.

## Risks / Trade-offs

- No behavior change — same serialize/deserialize logic, same paths, same error handling. Rollback is a single file revert.
