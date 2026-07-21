## Context

The history bar currently has five buttons: Delete, Copy, Previous (`<`), Next (`>`), and Clear. Only Copy and Clear have any enable/disable logic:
- Copy is shown/hidden based on selection (`SetActionButtonVisible`)
- Clear is disabled during LLM processing (`SetClearHistoryButtonEnabled`, called from `MainController.SetProcessingState`)

Delete, Previous, and Next are always enabled regardless of whether they can perform useful work. A `SetClearHistoryButtonEnabled` pattern already exists in `HistoryView` — it exposes a setter method that the controller calls. This change extends that pattern to the remaining buttons.

The state needed to decide enable/disable is already available:
- **Selection**: `historyView.GetNext()` returns first selected row, or 0 if none
- **Branch position**: `getHistoryInfoCommand.Execute()` returns `"current/total"` (e.g., `"2/5"`)

No new commands, services, or files are needed. This is purely controller → view coordination.

## Goals / Non-Goals

**Goals:**
- Delete button disabled when no message is selected
- Previous/Next buttons disabled when at edge branches
- Previous/Next buttons hidden entirely when there is only one history branch
- Button states recalculated automatically after any state-changing event (list rebuild, selection change, branch navigation)
- Follow the existing `SetClearHistoryButtonEnabled` pattern

**Non-Goals:**
- Changing Clear button behavior (already handled)
- Changing Copy button behavior (already handled)
- Keyboard shortcuts for history navigation
- Animations or transitions

## Decisions

### Decision 1: Centralize state calculation in `UpdateButtonStates()`

**Chosen**: Single method on `HistoryViewController` that reads all relevant state and pushes updates to the view.

**Alternatives considered**:
- Scatter enable/disable calls at each call site → duplicates logic, easy to miss a call site
- Put logic in `HistoryView` → violates architecture (views are structure-only, no logic)

### Decision 2: Hide Previous/Next when only one branch, disable when at edge

**Chosen**: Two-tier approach:
- `totalBranches == 1` → hide both buttons (they're useless clutter)
- `currentBranch == 1` → disable Previous (at first branch, can't go back)
- `currentBranch == totalBranches` → disable Next (at last branch, can't go forward)

Using both visibility and enabled states is more informative than simply hiding. A disabled button tells the user "this action exists but isn't available right now"; a hidden button says "this action doesn't apply at all."

### Decision 3: No new commands

**Chosen**: `UpdateButtonStates()` reads from the existing `getHistoryInfoCommand` and the view's own `GetNext()`. Both are read-only operations on services/views, which is permitted for controllers per the architecture rules.

## Risks / Trade-offs

- **Branch parsing fragility**: `getHistoryInfoCommand.Execute()` returns a `"current/total"` string. If the format changes, parsing breaks. → Mitigation: the format is defined by `Session.GetHistoryInfo()` which returns `currentHistoryIndex "/" histories.Length` — a simple, stable format unlikely to change.
- **Selection check after list rebuild**: `UpdateChatHistoryView()` rebuilds the list and loses selection, so Delete will correctly be disabled. If a future change preserves selection across rebuilds, the state logic still works correctly.
