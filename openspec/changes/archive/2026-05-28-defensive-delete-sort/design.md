## Context

`DeleteMessageCommand.Execute(selectedIndices)` uses `messages.RemoveAt(index)` in a loop. AHK array removal shifts subsequent elements down by one. If indices are processed in non-descending order, removing index 3 shifts index 5 to index 4, and the subsequent removal at index 5 deletes the wrong element. The only caller (`HistoryViewController.DeleteSelectedMessage()`) already sorts descending, so no bug exists today — but the command relies on an undocumented caller-side invariant.

## Goals / Non-Goals

**Goals:**
- Make `DeleteMessageCommand` self-sufficient — it should work correctly for any input order

**Non-Goals:**
- Do NOT change the caller (`HistoryViewController`)
- Do NOT change the removal algorithm (still uses `RemoveAt`)
- Do NOT add new methods to `SessionManager`

## Decisions

### Decision: Sort descending inside the command

Move the insertion sort from `HistoryViewController._SortDescending()` into `DeleteMessageCommand.Execute()`.

**Rationale**: Defense in depth. The command owns the invariant (descending order is required for correct removal), so it should enforce it. The caller's existing sort remains as harmless redundancy — no reason to remove it.

**Alternative considered (rebuild instead of remove)**: Build a new array excluding deleted indices, then replace the session's messages. Rejected because `SessionManager` has no `SetMessages()` method and adding one for this minor fix is over-engineering.

## Risks / Trade-offs

**Risk**: The command now sorts a potentially-large array of indices.  
→ **Mitigation**: In practice, users rarely delete more than 10 messages at once. The insertion sort is O(n²) but n is tiny. If this becomes a bottleneck, a faster sort can be added later.

**Risk**: Duplicate sort (caller + command) is wasteful.  
→ **Mitigation**: Harmless — the caller's sort still runs, and the command's sort on an already-sorted array is 0 swaps. Zero real cost.
