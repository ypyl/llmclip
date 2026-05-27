## Context

Currently, when a user selects a system prompt with an `input_template` field, `SettingsController.SystemPromptChanged()` calls `ConfigurationService.GetInputTemplate()` and populates the prompt input box via `PromptView.SetValue()`. However, when the user clicks "Reset All", `MainController.ResetAll()` resets the session and refreshes the UI via `UpdateSessionUI()` — but never re-applies the `input_template`. The input box ends up empty, which is inconsistent with the initial prompt selection behavior.

`UpdateSessionUI()` already sets the system prompt dropdown to the correct value (`SetSystemPromptValue`), so the selected prompt is known. The missing step is reading the `input_template` for that prompt and writing it to the input box.

## Goals / Non-Goals

**Goals:**
- After Reset All, restore the `input_template` of the currently selected system prompt to the prompt input box.
- Match the behavior already implemented in `SettingsController.SystemPromptChanged()`.
- Zero changes to commands, services, or views.

**Non-Goals:**
- Changing what Reset All resets (history, context, processing state — all untouched).
- Adding a config option or preference. This is always-on behavior.
- Affecting sessions without an `input_template` (they remain empty after reset, as expected).

## Decisions

### Decision 1: Add input_template restoration to `MainController.ResetAll()`

**Chosen**: Add the template restoration directly in `MainController.ResetAll()`, after `UpdateSessionUI()` returns.

**Rationale**:
- `ResetAll()` is already responsible for post-reset UI coordination.
- Adding it to `UpdateSessionUI()` would couple session-switching logic (where `UpdateSessionUI` is also used) with reset-specific behavior — `UpdateSessionUI` is called from many places and template restoration is only desired on reset.
- Keeps the change minimal (3 lines of AHK).

**Alternative considered**: Modify `SettingsController.SystemPromptChanged()` to be called from `ResetAll`. Rejected because `SystemPromptChanged()` also mutates the session's system prompt index via a command, which is unnecessary and wrong — the session already has the correct prompt after reset (ResetSesssion preserves `systemPromptIndex` and `llmType`).

### Decision 2: Read from `ConfigurationService` (read-only) and write to `MainView`

**Chosen**: Use `this.configManager.GetInputTemplate(modelIndex, promptIndex)` and `this.view.SetPromptValue(template)`.

**Rationale**:
- Controller reading from a Service is allowed (read-only access).
- Controller writing to a View is the View's sole purpose.
- No layer boundary violations — no new command needed since no service state is mutated.

## Risks / Trade-offs

- **Risk**: If `UpdateSessionUI()` is later restructured to clear the prompt box, this code would be overwritten. → **Mitigation**: Place the template restoration AFTER `UpdateSessionUI()` in the method body.
- **Trade-off**: For prompts without an `input_template`, the input remains empty. This is the correct and desired behavior — matching how a fresh prompt selection also leaves the box empty when no template exists.
