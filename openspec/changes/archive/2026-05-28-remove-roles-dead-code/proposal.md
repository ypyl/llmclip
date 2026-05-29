## Why

The `Roles` class in `Services/Configuration/Roles.ahk` is permanently disabled via `ROLES_DISABLED := true`. Its `GetPromptsForProvider()` always returns `[]`, causing every caller to fall back to all system prompts. Yet `roles.json` is still parsed from disk on every startup and every `Reload()` call, and the class is instantiated and wired through `ConfigurationService`. This is wasted I/O, wasted memory, and confusion for contributors reading the code.

## What Changes

- Delete `Services/Configuration/Roles.ahk`
- Remove `#Include Roles.ahk` from `ConfigurationService.ahk`
- Remove `rolesManager` property, instantiation, and `Reload()` call from `ConfigurationService`
- Simplify `GetVisiblePrompts()` to directly call `systemPromptsManager.GetNames()` without the `rolesManager` detour
- `roles.json` file is left in place (harmless, user may still have it) but no longer parsed at runtime

## Capabilities

### New Capabilities
<!-- None — dead code removal -->

### Modified Capabilities
<!-- None -->

## Impact

- **Deleted**: `Services/Configuration/Roles.ahk`
- **Modified**: `Services/Configuration/ConfigurationService.ahk` — remove include, property, instantiation, and simplify `GetVisiblePrompts()`
- **No behavioral changes** — all prompts already visible to all providers
