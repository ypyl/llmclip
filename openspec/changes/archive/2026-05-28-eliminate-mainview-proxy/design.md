## Context

`MainView` acts as a facade between `MainController` and 6 sub-views. But sub-controllers (`HistoryViewController`, `SettingsController`, etc.) already access sub-views directly via `this.mainView.xxxView`. The facade is inconsistent and adds unnecessary indirection.

## Goals / Non-Goals

**Goals:**
- Remove proxy methods from `MainView` — it becomes pure UI structure
- `MainController` accesses sub-views directly, matching the sub-controller pattern
- Zero behavioral changes

**Non-Goals:**
- Do NOT change how sub-controllers access views
- Do NOT restructure `BuildUI()` or `OnResize()`
- Do NOT change any controller logic

## Decisions

### Decision: Add sub-view properties to MainController

Add to `MainController`:
```ahk
promptView := ""
contextView := ""
historyView := ""
menuView := ""
topControlsView := ""
responseView := ""
```

Populate them via `SetView()` after `MainView` is constructed:
```ahk
controller.SetView(mainView, mainView.promptView, mainView.contextView, ...)
```

Then replace `this.view.GetPromptValue()` → `this.promptView.GetValue()`, etc.

### Decision: Update call sites mechanically

Each `this.view.X()` maps to a specific sub-view:

| Proxy | Becomes |
|-------|---------|
| `this.view.GetPromptValue()` | `this.promptView.GetValue()` |
| `this.view.SetAskButtonText()` | `this.promptView.SetAskButtonText()` |
| `this.view.GetContextBoxValue()` | `this.contextView.GetValue()` |
| `this.view.UpdateBatchMode()` | `this.menuView.UpdateBatchMode()` |
| `this.view.UpdateModelMenu()` | `this.menuView.UpdateModelMenu()` |
| `this.view.ShowError()` | `MsgBox(...)` (it was a proxy too) |
| `this.view.GetResponseCtrHwnd()` | `this.responseView.GetHwnd()` |
| `this.view.guiShown` | `this.mainView.guiShown` (keep on MainView) |
| `this.view.SetClearHistoryButtonEnabled()` | `this.historyView.SetClearHistoryButtonEnabled()` |
| `this.view.SetResetAllButtonEnabled()` | `this.topControlsView.SetResetButtonEnabled()` |
| `this.view.SetSessionSelectValue()` | `this.menuView.UpdateSessionMenu()` |

### Decision: Keep `guiShown` on MainView

`guiShown` is a window-level flag that conceptually belongs to `MainView` (the window owner). Keep it there, accessed as `this.mainView.guiShown`.

## Risks / Trade-offs

**Risk**: Large search-and-replace across ~50 call sites → easy to miss one.  
→ **Mitigation**: Grep for `this.view\.` after changes to verify zero remaining references.

**Risk**: `MainController` dependency list grows (6 new view references).  
→ **Mitigation**: This is already the case — the controller accesses these views through `this.view`, just indirectly. Making it direct is honest.
