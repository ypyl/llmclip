## 1. MainView — remove proxy methods

- [x] 1.1 Remove all `; Proxies for controllers...` methods (~25 one-liners)
- [x] 1.2 Remove the 5 fat-arrow property proxies (`modelMenu`, `menuBar`, `toolsMenu`, `historyMenu`)
- [x] 1.3 Update any remaining references to the removed proxies (e.g., `PromptView.Create()` calls `this` — verify it doesn't use removed proxies)

## 2. MainController — add direct sub-view access

- [x] 2.1 Add sub-view properties to `MainController`: `promptView`, `contextView`, `historyView`, `menuView`, `topControlsView`, `responseView`, `mainView`
- [x] 2.2 Update `SetView()` to accept and store all sub-view references
- [x] 2.3 Replace `this.view.GetPromptValue()` → `this.promptView.GetValue()` (all prompt-related calls)
- [x] 2.4 Replace `this.view.GetContextBoxValue()` → `this.contextView.GetValue()` (all context-related calls)
- [x] 2.5 Replace `this.view.UpdateBatchMode()` → `this.menuView.UpdateBatchMode()` (all menu-related calls)
- [x] 2.6 Replace `this.view.SetClearHistoryButtonEnabled()` → `this.historyView.SetClearHistoryButtonEnabled()` (all history-related calls)
- [x] 2.7 Replace `this.view.SetResetAllButtonEnabled()` → `this.topControlsView.SetResetButtonEnabled()` (all top controls calls)
- [x] 2.8 Replace `this.view.GetResponseCtrHwnd()` → `this.responseView.GetHwnd()` (response view calls)
- [x] 2.9 Replace `this.view.Show()` / `this.view.guiShown` → `this.mainView.Show()` / `this.mainView.guiShown`
- [x] 2.10 Replace `this.view.ShowError()` / `this.view.ShowMessage()` / `this.view.ShowSaveFileDialog()` / `this.view.ShowOpenFileDialog()` → inline `MsgBox`/`FileSelect` calls

## 3. App.ahk — wiring update

- [x] 3.1 Update `controller.SetView(mainView)` to pass all sub-view references
- [x] 3.2 Verify no other code references the removed MainView proxies

## 4. Verification

- [x] 4.1 Grep for `this\.view\.` in `Controllers/MainController.ahk` — zero results ✓
- [x] 4.2 Manual smoke test: launch `main.ahk`, verify UI renders, send a message, change settings — all interactions work (needs manual AHK v2 execution)
