## Why

The History → Compress feature is dead code. The History menu bar entry contains exactly one item ("Compress"), and `GetCompressionPrompt()` always returns a hardcoded string (menu is always enabled with no meaningful state distinction). Removing it eliminates ~120 lines of unused code across 11 files, simplifies `SetProcessingState()` from 5 branches to 4, and removes an LLM call path that was never exercised.

## What Changes

- **BREAKING**: Remove History top-level menu bar entry (had only "Compress" item)
- **BREAKING**: Remove `CompressHistoryCommand` and `GetCompressionMenuStateCommand`
- Remove `LLMService.CompressHistory()` method
- Remove `SessionManager` compression methods: `FormatMessagesForCompression`, `FormatMessagesForCompressionForSession`, `ReplaceWithCompressed`, `ReplaceWithCompressedForSession`
- Remove `ConfigurationService.GetCompressionPrompt()`
- Remove `ProcessingState.COMPRESSING` constant
- Remove `SettingsController.UpdateCompressionMenuState()` and its callers
- Remove `MainController.CompressHistory()` handler and `COMPRESSING` branch from `SetProcessingState()`
- Remove `MenuView` history menu creation, field, and `UpdateCompressionState()` method
- Remove `MainView.BuildUI()` call to `UpdateCompressionMenuState()`
- Remove compressing-related `#Include` lines and command wiring from `App.ahk`
- Remove `openspec/specs/compression-service/` spec directory
- Update README to remove compression bullet point

## Capabilities

### New Capabilities

None — this is a pure removal.

### Modified Capabilities

- `compression-service`: Entire capability removed. The spec is deleted — no delta needed.

## Impact

- **2 files deleted**: `Commands/CompressHistoryCommand.ahk`, `Commands/GetCompressionMenuStateCommand.ahk`
- **10 files modified**: `App.ahk`, `Controllers/MainController.ahk`, `Controllers/SettingsController.ahk`, `ui/MenuView.ahk`, `ui/MainView.ahk`, `Services/SessionManager.ahk`, `Services/LLM/LLMService.ahk`, `Services/Configuration/ConfigurationService.ahk`, `Services/ProcessingState.ahk`, `README.md`
- **1 spec deleted**: `openspec/specs/compression-service/`
- **Layers touched**: Command (2 deletions), Controller (2), View (2), Service (4), Composition Root
- **No runtime config changes**: `providers/`, `prompts/`, `keys.ini` unaffected
- **No UI regressions**: History View (chat-history ListView) is unrelated and untouched
- **Verification**: `grep -rn "Compress\|compress" --include="*.ahk" .` should return zero results after implementation
