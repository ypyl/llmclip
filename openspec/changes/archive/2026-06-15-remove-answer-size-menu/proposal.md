## Why

The "Answer Size" menu (Small / Default / Long) injects a verbosity instruction as an extra user message before each LLM call. This is redundant — users can already control verbosity by wording their prompts directly. The menu clutters the UI and introduces unnecessary complexity across 8 files spanning View, Controller, Command, Service, and state persistence layers.

## What Changes

- Remove the "Answer Size" menu from the menu bar entirely (menu bar goes from 5 entries to 4: File, Session, Tools, Model)
- Remove `ChangeAnswerSizeCommand` (entire file deleted)
- Remove `answerSize` field and `SetAnswerSize()` from `SessionManager`
- Remove answer-size injection logic (3-branch conditional) from `LLMService.SendToLLM()` — all calls behave as "Default" (no injected instruction)
- Remove answer-size persistence from `SaveStateOnExitCommand` and `LoadStateOnStartCommand`
- Remove `SelectAnswerSize()` from `SettingsController`
- Remove `answerSizeMenu` field, creation, menu bar entry, and `UpdateAnswerSizeMenu()` from `MenuView`
- Clean up `App.ahk` wiring (include, instantiation, constructor param)
- Remove `answerSize` read from `SendToLLMCommand` (no longer needed since `LLMService.SendToLLM()` drops the parameter)

## Capabilities

### New Capabilities

_None — this is a removal, not a new capability._

### Modified Capabilities

_None — no existing spec-level requirements change. The LLM sending behavior is identical to the prior "Default" mode (no verbosity instruction injected)._

## Impact

- **View layer**: `ui/MenuView.ahk` — 1 field, ~6 lines of menu creation, 1 method removed
- **Controller layer**: `Controllers/SettingsController.ahk` — 1 field, 1 constructor param, 1 method removed
- **Command layer**: `Commands/ChangeAnswerSizeCommand.ahk` — file deleted; `Commands/SendToLLMCommand.ahk` — 1 line removed; `Commands/SaveStateOnExitCommand.ahk` — 1 line removed; `Commands/LoadStateOnStartCommand.ahk` — ~6 lines removed
- **Service layer**: `Services/SessionManager.ahk` — 1 field + 1 setter removed; `Services/LLM/LLMService.ahk` — 1 parameter + ~8 lines of injection logic removed
- **Composition root**: `App.ahk` — 1 `#Include`, 1 instantiation, 1 constructor arg removed
- **State**: Existing `state.json` entries with `"answerSize"` key are harmlessly ignored by updated loader; next save naturally drops the key
- **No breaking changes**: All removed code is internal plumbing — no external API, no provider config, no user-facing contract beyond the menu itself
