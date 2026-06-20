## Context

`HistoryViewController.__New()` currently contains:

```ahk
if (this.webViewManager) {
    this.webViewManager.SetSaveEditCallback(ObjBindMethod(this, "OnMessageEdited"))
}
```

This mutates `WebViewManager` (a Service — defined in `services/WebViewManager.ahk`) during controller construction. The architecture (§3) states controllers may only *read* services, never mutate them.

`App.ahk` is the designated composition root where all wiring between layers happens via post-construction property/method assignment. Multiple existing examples demonstrate this pattern:

```ahk
; App.ahk — existing wiring patterns
settingsContr.SetViews(this.view.menuView, this.view.promptView)
settingsContr.SetOnSessionChanged((*) => this.controller.UpdateSessionUI())
settingsContr.SetOnSystemPromptChanged((*) => this.controller.RefreshOnSystemPromptChanged())
this.controller.SetSubControllers(ctxView, histView, settingsContr)
this.controller.SetCommands(...)
this.view.SetSubControllers(ctxView, histView, settingsContr)
```

The `SetSaveEditCallback` wiring is the same class of operation and should follow this pattern.

## Goals / Non-Goals

**Goals:**
- Eliminate the architecture violation: controller no longer mutates a service
- Keep the wiring in `App.ahk`, consistent with all other cross-layer wiring
- Zero behavioral change — `OnMessageEdited` callback must fire identically

**Non-Goals:**
- Refactoring `WebViewManager`'s callback mechanism
- Changing how `OnMessageEdited` works
- Any other architecture cleanup

## Decisions

### Decision 1: Move wiring to App.ahk rather than route through a Command

**Chosen**: Direct post-construction wiring in `App.ahk`.

**Rationale**: Setting a callback is *wiring*, not *mutation*. It configures the dependency graph before the application runs, not during operation. This is precisely what `App.ahk` does for all other callback registrations (`SetOnSessionChanged`, `SetOnSystemPromptChanged`, `SetViews`, etc.). Creating a Command for this would add indirection without benefit — Commands are for operational mutations, not initialization wiring.

**Alternative considered**: Create a `WireHistoryViewControllerCommand`. Rejected because it would be the only Command in the codebase that does initialization wiring rather than operational state changes, breaking the Command pattern's semantics.

### Decision 2: Wire directly against `wv` rather than `histView.webViewManager`

**Chosen**: `wv.SetSaveEditCallback(ObjBindMethod(histView, "OnMessageEdited"))` in `App.ahk`.

**Rationale**: `wv` is already in scope in `App.ahk` (it's the `WebViewManager` instance created at the top of `__New()`). Using it directly is simpler and keeps the wiring visible in one place. The `webViewManager` parameter to `HistoryViewController.__New()` remains for read-access within the controller.

**Alternative considered**: Call `histView.webViewManager.SetSaveEditCallback(...)` from `App.ahk`. Rejected — accessing `histView.webViewManager` just to call a method on it is indirect and obscures the fact that `App.ahk` owns the wiring.

## Risks / Trade-offs

- **[Risk] Breaking the save-edit flow**: If the `SetSaveEditCallback` call is accidentally omitted or misordered, messages edited in the WebView won't be saved back to the session. → **Mitigation**: Manual smoke test — open a conversation, edit a message in WebView, verify it persists in the session list. Trivial to verify.
- **[Trade-off] `HistoryViewController` constructor receives `webViewManager` but doesn't use it for wiring**: Now the parameter exists solely for the `this.webViewManager` reference used in the constructor body for nothing except the removed `SetSaveEditCallback` call. However, the controller still holds the reference for potential future read-access (e.g., reading WebView state). If read-access is never needed, the parameter can be removed in a future cleanup.
