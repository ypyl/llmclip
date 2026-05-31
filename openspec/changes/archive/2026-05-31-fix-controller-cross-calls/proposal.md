## Why

`SettingsController` reaches through `MainView` to call methods on `MainController`, `ContextViewController`, and `HistoryViewController` — violating the architecture's rule that controller-to-controller calls are forbidden. This creates a hidden dependency chain (`SettingsController → MainView → other controllers`) where MainView acts as an unauthorized service locator. Fixing this removes the last remaining architecture violation in the controllers layer and prevents the pattern from propagating.

## What Changes

- **SettingsController**: Replace 4 cross-controller call sites with two opaque callbacks (`onSessionChanged`, `onSystemPromptChanged`), using the architecture's own sanctioned property-assignment-after-construction wiring pattern
- **MainController**: Add a `RefreshOnSystemPromptChanged()` method to handle the partial UI refresh that a system prompt change requires (lightweight version of `UpdateSessionUI` that doesn't clear the response area)
- **App.ahk**: Wire the two callbacks after SettingsController construction; simplify `SetViews()` signature by removing the unused `mainView` parameter
- **ARCHITECTURE.md**: Clarify that the property-assignment wiring pattern also applies to sub-controller → parent-controller notifications, making the pattern explicit for future developers

## Capabilities

### New Capabilities

- `controller-notification-callbacks`: Sub-controllers notify parent controllers through opaque callbacks rather than reaching through View back-references. The callback pattern uses the same property-assignment-after-construction technique already prescribed for View↔Controller wiring.

### Modified Capabilities

<!-- None — no existing spec requirements change -->

## Impact

- **Controllers layer**: `SettingsController` loses dependency on `MainView` for cross-controller access; `MainController` gains one new method
- **App.ahk**: 3 lines of wiring added, 1 parameter removed from `SetViews()`
- **Views**: No changes — `MainView` still holds sub-controller references for `BuildUI()` wiring, but controllers no longer read them as a backdoor
- **No breaking changes**: All command invocations and service mutations remain identical. Menu events still flow through SettingsController. User-visible behavior is unchanged.
