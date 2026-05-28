## 1. ConfigurationService — toolOverrides Map and read logic

- [x] 1.1 Add `toolOverrides := Map()` property to `ConfigurationService`
- [x] 1.2 Update `IsToolEnabled()` to check `toolOverrides` first, falling back to provider defaults
- [x] 1.3 Update `SetToolEnabled()` to write to `toolOverrides` instead of mutating the providers cache
- [x] 1.4 Ensure `Reload()` does not clear `toolOverrides` — only rebuild providers from JSON

## 2. State persistence — save and load tool overrides

- [x] 2.1 Update `SaveStateOnExitCommand.Execute()` to include `toolOverrides` in the saved state object
- [x] 2.2 Update `LoadStateOnStartCommand.Execute()` to restore `toolOverrides` from state, with a guard for missing key (graceful on first run or upgrade)

## 3. Integration

- [x] 3.1 Launch `main.ahk`, toggle tools, reload settings, restart app — verify preferences survive (needs manual AHK v2 execution)
