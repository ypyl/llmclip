## ADDED Requirements

### Requirement: Sub-controller notifies parent via opaque callback

When a sub-controller needs to trigger a refresh or coordination action that spans beyond its own view scope, it SHALL invoke an opaque callback rather than reaching through a View to access other controllers. The callback MUST be set via property assignment after construction in `App.ahk`, using the same pattern already prescribed for View↔Controller wiring.

The sub-controller MUST NOT know the identity of the callback target. It SHALL guard calls with a nil check to safely degrade if wiring is omitted.

#### Scenario: Session change triggers full UI refresh

- **WHEN** user selects a different session from the settings menu
- **THEN** `SettingsController.SelectSession()` executes `SwitchSessionCommand` to mutate session state, then calls `this.onSessionChanged()` to trigger a full UI refresh
- **AND** `SettingsController` does not access `mainView.controller` or any other controller reference

#### Scenario: System prompt change triggers partial UI refresh

- **WHEN** user changes the system prompt from the dropdown
- **THEN** `SettingsController.SystemPromptChanged()` executes `ChangeSystemPromptCommand` to mutate session state, updates its own `promptView` with the new input template, then calls `this.onSystemPromptChanged()` to refresh context view, history view, and session select label
- **AND** the response area (chat display) is NOT cleared

#### Scenario: Callback not wired — no crash

- **WHEN** `SettingsController` invokes a callback that was never set (nil)
- **THEN** the invocation is silently skipped due to `if (this.onSessionChanged)` guard
- **AND** the application continues running without error

### Requirement: Callbacks wired in App.ahk composition root

All sub-controller callback wiring SHALL occur in `App.ahk`, immediately after sub-controller construction and before the application starts. The wiring SHALL use `ObjBindMethod` to create BoundFunc objects that bind the parent controller's method without exposing the parent reference to the sub-controller.

#### Scenario: Wiring occurs during application initialization

- **WHEN** `App.__New()` constructs `SettingsController` and `MainController`
- **THEN** `settingsContr.SetOnSessionChanged(ObjBindMethod(this.controller, "UpdateSessionUI"))` is called
- **AND** `settingsContr.SetOnSystemPromptChanged(ObjBindMethod(this.controller, "RefreshOnSystemPromptChanged"))` is called
- **AND** these calls happen before `App.Start()` is invoked

### Requirement: MainController provides partial refresh method

`MainController` SHALL expose a `RefreshOnSystemPromptChanged()` method that refreshes only the sub-views affected by a system prompt change: context view, history view, and session select label. This method MUST NOT clear the response area or modify the model menu, tools menu, or system prompt dropdown.

#### Scenario: RefreshOnSystemPromptChanged refreshes sub-views only

- **WHEN** `MainController.RefreshOnSystemPromptChanged()` is called
- **THEN** `this.contextViewController.UpdateContextView()` is invoked
- **AND** `this.historyViewController.UpdateChatHistoryView()` is invoked
- **AND** `this.mainView.SetSessionSelectValue(this.sessionManager.currentSessionIndex)` is invoked
- **AND** the response area is not cleared (no call to `RenderMarkdown("")`)
- **AND** model menu, tools menu, and system prompt dropdown are not modified

### Requirement: SettingsController no longer depends on MainView for cross-controller access

After callback wiring is in place, `SettingsController` SHALL NOT use `this.mainView` to access `controller`, `contextViewController`, `historyViewController`, or any method on other controllers. The `mainView` parameter SHALL be removed from `SetViews()` once it has no remaining uses.

#### Scenario: SetViews no longer accepts mainView

- **WHEN** `SettingsController.SetViews()` is called during wiring
- **THEN** it accepts only `menuView` and `promptView` parameters
- **AND** the `this.mainView` property is either removed or left unset
