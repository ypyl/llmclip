## Why

The "Extract Notes" feature (History menu → Extract Notes) is dead code — it is never used in practice. Removing it reduces maintenance surface, trims 3 files entirely, and simplifies wiring in `App.ahk` and `MainController.ahk`.

## What Changes

- Remove the full feature stack: `ExtractLearningsCommand`, `NotesController`, `NotesView`
- Remove the `ExtractLearnings()` method from `LLMService` (called only by this feature)
- Remove the `GetLearningsPrompt()` helper from `ConfigurationService` (called only by this feature)
- Remove the `EXTRACTING` processing state constant (used only by this feature)
- Remove the "Extract Notes" menu item from the History submenu
- Clean up all wiring, `#Include` directives, and field declarations in `App.ahk` and `MainController.ahk`

No new capabilities. No requirement changes to existing capabilities. This is a pure removal.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None.

## Impact

- **Deleted files (3)**: `Commands/ExtractLearningsCommand.ahk`, `Controllers/NotesController.ahk`, `ui/NotesView.ahk`
- **Modified files (6)**: `App.ahk`, `Controllers/MainController.ahk`, `Services/ProcessingState.ahk`, `Services/LLM/LLMService.ahk`, `Services/Configuration/ConfigurationService.ahk`, `ui/MenuView.ahk`
- **No breaking changes**: No feature depends on any of the removed code
- **No runtime config impact**: The `learnings_prompt` setting becomes unused but removing it from user configs is optional and out of scope
