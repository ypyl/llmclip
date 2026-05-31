## Context

`SettingsController` is a sub-controller that handles settings menu events (model selection, session switching, system prompt changes, tool toggles). It holds a reference to `mainView` (set via `SetViews()`), and uses `mainView` to reach three other controllers:

```ahk
; SelectSession — needs full UI rebuild after session switch
this.mainView.controller.UpdateSessionUI()

; SystemPromptChanged — needs partial refresh after prompt change
this.mainView.contextViewController.UpdateContextView()
this.mainView.historyViewController.UpdateChatHistoryView()
this.mainView.SetSessionSelectValue(...)
```

This violates the architecture rule `⛔ Controller → Controller calls` and turns `MainView` (which should be passive structure) into a service locator.

The architecture's own wiring pattern (§2) already prescribes property-assignment-after-construction for breaking View↔Controller circular dependencies. The same technique applies here.

## Goals / Non-Goals

**Goals:**
- Replace all 4 cross-controller call sites with opaque callback invocations
- SettingsController must not know the identity of the listener
- The callback wiring must happen in `App.ahk` (composition root), not inside any controller
- Remove `mainView` from SettingsController if it's no longer used after the refactor

**Non-Goals:**
- Broader sub-controller refactor (RecordingController, ContextViewController, HistoryViewController are already clean)
- Event bus or notification system
- Changing how menu events are routed (menu events still go directly to SettingsController)
- Modifying any command or service

## Decisions

### Decision 1: Two callbacks, not one

Two callbacks instead of a single `onRefreshNeeded` with a type parameter:

| Callback | Trigger | Maps to |
|----------|---------|---------|
| `onSessionChanged` | `SelectSession()` | `MainController.UpdateSessionUI()` — full refresh including response clear |
| `onSystemPromptChanged` | `SystemPromptChanged()` | `MainController.RefreshOnSystemPromptChanged()` — partial refresh, no response clear |

**Why not a single callback?** `UpdateSessionUI()` clears the response area (`RenderMarkdown("")`). Calling it when only the system prompt changes would incorrectly wipe the current conversation display. A separate, lighter method avoids this regression.

**Alternative considered:** Create a parameterized callback `onRefreshNeeded("session")` / `onRefreshNeeded("prompt")`. Rejected because string dispatch is fragile and AHK lacks enum support — two explicit callbacks are clearer.

### Decision 2: `RefreshOnSystemPromptChanged()` as a new MainController method

This method does exactly what `SystemPromptChanged` currently reaches across to do:
- `this.contextViewController.UpdateContextView()`
- `this.historyViewController.UpdateChatHistoryView()`
- `this.mainView.SetSessionSelectValue(this.sessionManager.currentSessionIndex)`

**Why not reuse `UpdateSessionUI()`?** As described above — it clears the response area. 

**Why not inline in the callback?** The callback is a BoundFunc — having a named method on MainController makes the intent clear and testable-by-inspection.

### Decision 3: BoundFunc via ObjBindMethod

```ahk
settingsContr.SetOnSessionChanged(
    ObjBindMethod(this.controller, "UpdateSessionUI"))
settingsContr.SetOnSystemPromptChanged(
    ObjBindMethod(this.controller, "RefreshOnSystemPromptChanged"))
```

`ObjBindMethod` creates a BoundFunc that calls the method on the bound object. SettingsController receives a callable value — it never sees the object reference.

**Alternative considered:** Event/notification system on SessionManager. Services would emit events, controllers subscribe. Rejected as over-engineered for two call sites in a single-developer project.

### Decision 4: Remove `mainView` from SettingsController.SetViews()

After the refactor, `SettingsController.mainView` has zero uses. The `SetViews()` signature changes:
```ahk
; Before
SetViews(menuView, promptView, mainView)
; After
SetViews(menuView, promptView)
```

And the call site in `App.ahk`:
```ahk
; Before
settingsContr.SetViews(this.view.menuView, this.view.promptView, this.view)
; After
settingsContr.SetViews(this.view.menuView, this.view.promptView)
```

This removes the service-locator backdoor entirely — no future sub-controller can accidentally reach through `mainView` to other controllers.

## Risks / Trade-offs

- **[Risk] Callback not wired** → `SettingsController` guards with `if (this.onSessionChanged)`. If wiring is missed, the UI doesn't refresh after session/prompt changes — no crash, but noticeable during testing.
- **[Risk] `RefreshOnSystemPromptChanged` drifts from `UpdateSessionUI`** → Both methods share the same parent-controller scope and call the same sub-controllers. Any future change that adds a sub-view refresh to one should add it to the other. This is documented in the method comment.
- **[Trade-off] Two callbacks instead of one** → Slightly more code in SettingsController and App.ahk, but eliminates the risk of accidentally clearing the response area.
- **[Trade-off] `mainView` removal** → If a future feature needs SettingsController to interact with MainView directly, the parameter must be re-added. But the architecture forbids this pattern, so removal is a feature, not a bug.
