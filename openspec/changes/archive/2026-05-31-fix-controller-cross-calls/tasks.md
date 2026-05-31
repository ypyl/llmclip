## 1. MainController — Add RefreshOnSystemPromptChanged method

- [x] 1.1 Add `RefreshOnSystemPromptChanged()` method to `MainController` that calls `this.contextViewController.UpdateContextView()`, `this.historyViewController.UpdateChatHistoryView()`, and `this.mainView.SetSessionSelectValue(this.sessionManager.currentSessionIndex)`
- [x] 1.2 Add a comment on the method noting it's the lightweight counterpart to `UpdateSessionUI()` and must stay in sync with any new sub-view refresh calls added there

## 2. SettingsController — Add callback properties and setters

- [x] 2.1 Add `onSessionChanged` and `onSystemPromptChanged` properties (initialized to empty string) to `SettingsController`
- [x] 2.2 Add `SetOnSessionChanged(callback)` and `SetOnSystemPromptChanged(callback)` setter methods

## 3. SettingsController — Replace cross-controller call sites

- [x] 3.1 In `SelectSession()`, replace `this.mainView.controller.UpdateSessionUI()` with `if (this.onSessionChanged) this.onSessionChanged()`
- [x] 3.2 In `SystemPromptChanged()`, replace the three cross-controller calls (`this.mainView.contextViewController.UpdateContextView()`, `this.mainView.historyViewController.UpdateChatHistoryView()`, `this.mainView.SetSessionSelectValue(...)`) with `if (this.onSystemPromptChanged) this.onSystemPromptChanged()`

## 4. SettingsController — Remove mainView dependency

- [x] 4.1 Change `SetViews(menuView, promptView, mainView)` to `SetViews(menuView, promptView)` — remove the `mainView` parameter and the `this.mainView := mainView` assignment
- [x] 4.2 Verify no other references to `this.mainView` remain in `SettingsController.ahk`

## 5. App.ahk — Wire callbacks

- [x] 5.1 After `settingsContr := SettingsController(...)`, add `settingsContr.SetOnSessionChanged(ObjBindMethod(this.controller, "UpdateSessionUI"))`
- [x] 5.2 Add `settingsContr.SetOnSystemPromptChanged(ObjBindMethod(this.controller, "RefreshOnSystemPromptChanged"))`
- [x] 5.3 Update `settingsContr.SetViews(...)` call to pass only two arguments: `this.view.menuView, this.view.promptView`

## 6. Documentation — Update ARCHITECTURE.md and CODE-AUDIT.md

- [x] 6.1 Add sub-controller wiring clarification to ARCHITECTURE.md §2 Wiring Pattern: "The same pattern applies when a sub-controller needs to notify its parent controller — set a callback on the sub-controller after construction rather than reaching through the View's back-references."
- [x] 6.2 Mark audit issue #3 as resolved in CODE-AUDIT.md (change header to ✅ FIXED, update executive summary counts, update recommendations, update compliance summary table)

## 7. Integration verification

- [x] 7.1 Run `main.ahk` and verify: switching sessions updates all UI components (model menu, session menu, system prompt, tools, context, history, response clear)
- [x] 7.2 Verify: changing system prompt refreshes context view, history view, and session select label WITHOUT clearing the response area
- [x] 7.3 Verify: selecting a model, toggling tools, and changing answer size still work correctly (no regression)
