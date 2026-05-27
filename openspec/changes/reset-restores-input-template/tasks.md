## 1. Controller Implementation

- [x] 1.1 Add `input_template` restoration logic to `MainController.ResetAll()`: after `this.UpdateSessionUI()`, read `GetInputTemplate` from `configManager` for the current model/prompt and call `this.view.SetPromptValue()` if a template exists
- [x] 1.2 Verify no `#Include` changes are needed in `App.ahk` (no new files created, only existing controller is modified)

## 2. Integration & Verification

- [ ] 2.1 Launch `main.ahk`, select a system prompt that has an `input_template`, verify the template appears in the input box, then edit the text, click "Reset All", and confirm the template is restored to the input box *(manual GUI verification)*
- [ ] 2.2 Select a system prompt WITHOUT an `input_template`, edit the input box, click "Reset All", and confirm the input box remains empty (no regression for prompts without templates) *(manual GUI verification)*
- [ ] 2.3 Confirm that Reset All still correctly clears session history, context items, and restores processing state to IDLE *(manual GUI verification)*
