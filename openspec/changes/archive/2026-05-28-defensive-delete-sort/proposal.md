## Why

`DeleteMessageCommand.Execute()` iterates over caller-supplied indices and removes them from the message array via `RemoveAt()`. If indices are not sorted in descending order, earlier removals shift later indices, causing wrong messages to be deleted. The single caller (`HistoryViewController`) pre-sorts descending, so the bug hasn't manifested — but the command has an implicit, undocumented contract that makes it fragile to future callers. Moving the sort into the command makes it self-defending.

## What Changes

- `DeleteMessageCommand.Execute()` sorts `selectedIndices` in descending order before iterating, so the command works correctly regardless of input order.
- No changes to the caller (`HistoryViewController`) — its existing sort is harmless redundancy.

## Capabilities

### New Capabilities
<!-- None — purely defensive, no new behavior -->

### Modified Capabilities
<!-- None — no requirement-level change -->

## Impact

- **Modified**: `Commands\DeleteMessageCommand.ahk` — add descending sort before the removal loop
- **No changes** to controllers, views, services, or any other files
