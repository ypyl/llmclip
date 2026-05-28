# tool-persistence

Tool enable/disable preferences are stored per-model in a `toolOverrides` Map, persisted to `state.json`, and survive configuration reloads and app restarts. Preferences are merged with provider defaults at read time.

## Requirements

### Requirement: Tool preferences are stored per-model
The system SHALL maintain a `toolOverrides` Map in `ConfigurationService` keyed by model identifier string (e.g., `"Groq/llama-3.3-70b-versatile"`) where each value is a Map of tool name to boolean. The overrides Map SHALL be separate from the provider defaults loaded from `providers.json`.

#### Scenario: User toggles a tool off
- **WHEN** `SetToolEnabled(modelIndex, "execute_powershell", false)` is called
- **THEN** `toolOverrides["Groq/llama-3.3-70b-versatile"]["execute_powershell"]` is set to `false`
- **AND** the providers cache loaded from `providers.json` is not modified

#### Scenario: User toggles a tool on that was off by default
- **WHEN** `SetToolEnabled(modelIndex, "web_search", true)` is called for a model that does not include `web_search` in its provider defaults
- **THEN** the override is stored as `true`
- **AND** subsequent `IsToolEnabled` calls return `true` for that model+tool

### Requirement: IsToolEnabled reads overrides before defaults
`IsToolEnabled(modelIndex, toolName)` SHALL check the `toolOverrides` Map for the given model first. If an explicit override exists, it SHALL be returned. If no override exists, the provider default from `providers.json` SHALL be used.

#### Scenario: Tool has an explicit override
- **WHEN** `IsToolEnabled(modelIndex, "execute_powershell")` is called
- **AND** `toolOverrides` contains `{ "Groq/llama-3.3-70b": { "execute_powershell": false } }`
- **THEN** the method returns `false` without consulting provider defaults

#### Scenario: Tool has no override — fall back to provider default
- **WHEN** `IsToolEnabled(modelIndex, "file_system")` is called
- **AND** `toolOverrides` has no entry for `"file_system"` under this model
- **THEN** the method checks the provider defaults from `providers.json`
- **AND** returns the default value

### Requirement: Tool preferences survive configuration reload
`ConfigurationService.Reload()` SHALL rebuild the providers cache from `providers.json` without clearing or modifying the `toolOverrides` Map. User tool preferences SHALL persist across reloads.

#### Scenario: Reload after tool toggle
- **WHEN** the user toggles `web_search` off for the current model
- **AND** `Reload()` is called (via Settings menu or after prompt creation)
- **THEN** `IsToolEnabled(modelIndex, "web_search")` still returns `false`
- **AND** all other tool preferences are preserved

### Requirement: Tool preferences persist in state.json
`SaveStateOnExitCommand.Execute()` SHALL serialize `toolOverrides` into `state.json` alongside other preferences. `LoadStateOnStartCommand.Execute()` SHALL restore `toolOverrides` from `state.json` on startup.

#### Scenario: Save tool preferences on exit
- **WHEN** `SaveStateOnExitCommand.Execute()` is called
- **THEN** `state.json` contains a `"toolOverrides"` key with per-model tool enablement state
- **AND** models with no user overrides are not included (to keep the file minimal)

#### Scenario: Load tool preferences on startup
- **WHEN** `LoadStateOnStartCommand.Execute()` is called and `state.json` contains `"toolOverrides"`
- **THEN** the overrides are restored into `ConfigurationService.toolOverrides`
- **AND** `IsToolEnabled` reflects the restored preferences

#### Scenario: No toolOverrides in state.json (first run or upgrade)
- **WHEN** `LoadStateOnStartCommand.Execute()` is called and `state.json` has no `"toolOverrides"` key
- **THEN** `ConfigurationService.toolOverrides` remains an empty Map
- **AND** all tools use provider defaults without error
