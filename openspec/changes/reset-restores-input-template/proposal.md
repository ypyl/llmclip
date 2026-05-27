## Why

When a user selects a system prompt that has an `input_template` (a pre-filled prompt text), the template is correctly placed into the prompt input box. However, clicking "Reset All" clears the input box and does not restore the template — the user must manually re-select the prompt from the dropdown to get the template back. This is inconsistent: "Reset All" should restore the session to its initial state, which includes the `input_template` if one exists for the current prompt.

## What Changes

- After "Reset All" resets the session, the `input_template` for the currently selected system prompt is re-applied to the prompt input box (if one exists).
- No changes to the reset logic itself — history, context, and processing state are still fully purged.
- The `input_template` restoration mirrors what `SettingsController.SystemPromptChanged()` already does when a prompt is explicitly selected.

## Capabilities

### New Capabilities
- `reset-input-template-restore`: The Reset All action restores the `input_template` of the currently selected system prompt to the prompt input box, matching the behavior when the prompt is initially selected.

### Modified Capabilities
<!-- None -->

## Impact

- Affected layers: **Controller** only (`MainController.ahk`). Reads from `ConfigurationService` (read-only, allowed) and writes to `PromptView` via `MainView.SetPromptValue()` (allowed).
- No layer boundary violations: no command needed since no service state is mutated.
- No `#Include` changes required.
- No changes to commands, services, or views.
