## ADDED Requirements

### Requirement: Reset All restores input template
The system SHALL restore the `input_template` of the currently selected system prompt to the prompt input box when the user clicks "Reset All", if and only if the selected prompt defines an `input_template`.

#### Scenario: Reset All with input template
- **WHEN** the current session has a system prompt with an `input_template` defined (e.g., `"input_template": "Translate the following: "`)
- **AND** the user clicks "Reset All"
- **THEN** the prompt input box SHALL contain the `input_template` text
- **AND** the session history, context items, and processing state SHALL be reset to initial state

#### Scenario: Reset All without input template
- **WHEN** the current session has a system prompt that does NOT define an `input_template`
- **AND** the user clicks "Reset All"
- **THEN** the prompt input box SHALL remain empty
- **AND** the session history, context items, and processing state SHALL be reset to initial state

#### Scenario: Reset All preserves system prompt selection
- **WHEN** the user clicks "Reset All"
- **THEN** the system prompt dropdown SHALL still show the same selected prompt as before the reset
- **AND** the `llmType` (model selection) SHALL remain unchanged
