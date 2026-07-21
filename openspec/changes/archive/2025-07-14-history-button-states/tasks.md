## 1. Add setter methods to HistoryView

- [x] 1.1 Add `SetDeleteButtonEnabled(enabled)` method to `ui/HistoryView.ahk` — sets `this.deleteMessageButton.Enabled`
- [x] 1.2 Add `SetPrevButtonEnabled(enabled)` and `SetPrevButtonVisible(visible)` methods to `ui/HistoryView.ahk`
- [x] 1.3 Add `SetNextButtonEnabled(enabled)` and `SetNextButtonVisible(visible)` methods to `ui/HistoryView.ahk`

## 2. Add UpdateButtonStates to HistoryViewController

- [x] 2.1 Add `UpdateButtonStates()` method to `controllers/HistoryViewController.ahk` that reads selection state (via `this.historyView.GetNext()`) and branch position (via `this.getHistoryInfoCommand.Execute()`), then calls the appropriate `Set*` methods on the view
- [x] 2.2 In `UpdateButtonStates()`, parse the `"current/total"` branch info string to determine Previous/Next enabled and visible states
- [x] 2.3 In `UpdateButtonStates()`, set Delete enabled only when `GetNext()` returns a non-zero row

## 3. Wire UpdateButtonStates into call sites

- [x] 3.1 Call `this.UpdateButtonStates()` at the end of `UpdateChatHistoryView()` after the list is rebuilt
- [x] 3.2 Call `this.UpdateButtonStates()` at the end of `ChatHistorySelect()` after Copy button visibility is set
- [x] 3.3 Call `this.UpdateButtonStates()` at the end of `NavigateHistoryPrevious()` — already covered by 3.1 (NavigateHistoryPrevious calls UpdateChatHistoryView which calls UpdateButtonStates)
- [x] 3.4 Call `this.UpdateButtonStates()` at the end of `NavigateHistoryNext()` — already covered by 3.1 (NavigateHistoryNext calls UpdateChatHistoryView which calls UpdateButtonStates)

## 4. Integration verification

- [ ] 4.1 Run `main.ahk`, verify Delete is disabled when no item is selected and enabled when an item is selected *(manual verification)*
- [ ] 4.2 Verify Previous/Next are hidden when there is only one history branch *(manual verification)*
- [ ] 4.3 Create a branch (edit a message), verify Previous is disabled at first branch and Next is disabled at last branch *(manual verification)*
- [ ] 4.4 Navigate between branches, verify Previous/Next states update correctly *(manual verification)*
