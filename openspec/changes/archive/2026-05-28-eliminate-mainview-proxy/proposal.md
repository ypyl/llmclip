## Why

`MainView` has ~30 one-line proxy methods that do nothing but delegate to sub-views (`historyView`, `contextView`, `promptView`, `menuView`, etc.). These proxies are only used by `MainController` — sub-controllers already access sub-views directly through `this.mainView.xxxView`. This creates two inconsistent patterns for the same operation and adds maintenance overhead: every new sub-view method requires a corresponding proxy in `MainView`. Removing the proxies makes `MainView` a pure UI structure (as the architecture mandates) and lets `MainController` access sub-views directly, consistent with how sub-controllers work.

## What Changes

- `MainController` receives direct references to all sub-views (`promptView`, `contextView`, `historyView`, `menuView`, `topControlsView`, `responseView`) via `SetView()` or a new setter.
- All `this.view.X()` calls in `MainController` become `this.promptView.X()`, `this.contextView.X()`, etc.
- ~30 proxy methods and ~5 fat-arrow property proxies removed from `MainView`.
- `MainView` retains `BuildUI()`, `OnResize()`, and sub-view creation — pure UI structure.
- `App.ahk` updated to pass sub-view references to `MainController` after `MainView` construction.

## Capabilities

### New Capabilities
<!-- None — pure refactoring, no behavior change -->

### Modified Capabilities
<!-- None -->

## Impact

- **Modified**: `ui\MainView.ahk` — remove ~35 proxy lines
- **Modified**: `Controllers\MainController.ahk` — ~50 call sites updated from `this.view.X` to direct sub-view access
- **Modified**: `App.ahk` — pass sub-view refs to MainController
- **No behavioral changes** — all features work identically
