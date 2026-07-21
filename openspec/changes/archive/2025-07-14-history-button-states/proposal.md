## Why

History bar buttons (Delete, Previous, Next) are always enabled even when clicking them does nothing — no item selected, already at the first history branch, or no branches to navigate. This creates false affordances: buttons that look actionable but silently no-op. Disabling or hiding these buttons when they can't perform useful work makes the UI honest and reduces confusion.

## What Changes

- **Delete** button disabled when no message is selected in the history list
- **Previous** (`<`) button disabled when at the first history branch, and hidden entirely when there is only one branch
- **Next** (`>`) button disabled when at the last history branch, and hidden entirely when there is only one branch
- Add `UpdateButtonStates()` method to `HistoryViewController` that recalculates all button states from current selection and history branch position
- Add enable/disable and visibility setter methods to `HistoryView` for Delete, Previous, and Next buttons (following the existing `SetClearHistoryButtonEnabled` pattern)

## Capabilities

### New Capabilities
- `history-button-states`: History bar buttons reflect their actual availability — disabled or hidden when clicking them would be a no-op

### Modified Capabilities
<!-- None — purely additive UI behavior, no existing requirements change -->

## Impact

- **Modified**: `ui/HistoryView.ahk` — add `SetDeleteButtonEnabled`, `SetPrevButtonEnabled`, `SetNextButtonEnabled`, `SetPrevButtonVisible`, `SetNextButtonVisible` methods
- **Modified**: `controllers/HistoryViewController.ahk` — add `UpdateButtonStates()` method, call it from `UpdateChatHistoryView`, `ChatHistorySelect`, and after navigation
- No new files, no new commands, no service changes — purely controller/view coordination
