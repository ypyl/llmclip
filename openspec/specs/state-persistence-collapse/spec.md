## Requirements

### Requirement: StateHelper provides unified Save and Load methods
`StateHelper` SHALL expose `Save(path, obj)` and `Load(path)` static methods that encapsulate the shared serialize/de-serialize logic. The existing named methods (`SaveState`, `LoadState`, `SaveConversation`, `LoadConversation`) SHALL delegate to these without duplicating the implementation.

#### Scenario: Save state via unified path
- **WHEN** `StateHelper.Save(path, obj)` is called with a valid path and object
- **THEN** the object is serialized to JSON and written to the specified file, replacing any existing file

#### Scenario: Load state via unified path
- **WHEN** `StateHelper.Load(path)` is called for a file that exists and contains valid JSON
- **THEN** the parsed object is returned

#### Scenario: Load missing file
- **WHEN** `StateHelper.Load(path)` is called for a file that does not exist
- **THEN** an empty string is returned

#### Scenario: Load corrupt file
- **WHEN** `StateHelper.Load(path)` is called for a file with invalid JSON
- **THEN** an empty string is returned (try/catch handles the parse error)

### Requirement: Named wrappers delegate without duplication
Existing named methods SHALL be one-line delegates to the unified methods, preserving their original signatures and behavior.

#### Scenario: SaveState delegates to Save
- **WHEN** `StateHelper.SaveState(obj)` is called
- **THEN** it delegates to `StateHelper.Save(StateHelper.GetStatePath(), obj)` with identical behavior

#### Scenario: LoadState delegates to Load
- **WHEN** `StateHelper.LoadState()` is called
- **THEN** it delegates to `StateHelper.Load(StateHelper.GetStatePath())` with identical behavior
