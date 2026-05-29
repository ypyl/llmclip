## 1. Remove Roles class

- [x] 1.1 Delete `Services/Configuration/Roles.ahk`
- [x] 1.2 Remove `#Include Roles.ahk` from `Services/Configuration/ConfigurationService.ahk`
- [x] 1.3 Remove `rolesManager := unset` property from `ConfigurationService`
- [x] 1.4 Remove `this.rolesManager := Roles()` from `ConfigurationService.__New()`
- [x] 1.5 Remove `this.rolesManager.Reload()` from `ConfigurationService.LoadAll()`
- [x] 1.6 Simplify `GetVisiblePrompts()` to call `this.systemPromptsManager.GetNames()` directly instead of going through `this.rolesManager.GetPromptsForProvider()`

## 2. Verification

- [x] 2.1 Verify `rolesManager` is not referenced anywhere else in the codebase
- [x] 2.2 Manual smoke test: launch `main.ahk`, verify prompts menu still shows all prompts for all providers (needs manual AHK v2 execution)
