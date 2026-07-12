# update-prompt-tool

LLM-callable tool that modifies existing system prompts — their text, input template, visibility, and display name — migrating inline prompts to the file-reference pattern when needed.

## Requirements

### Requirement: LLM can update an existing system prompt's text
The system SHALL provide an `update_prompt` tool that the LLM can call to modify an existing system prompt's text. If the prompt is stored as a file-reference (`value: ".\\foo.md"`), the tool SHALL overwrite the `.md` file. If the prompt is stored inline, the tool SHALL migrate it to the file-reference pattern by creating a `.md` file and updating the JSON metadata.

#### Scenario: Update a file-reference prompt's text
- **WHEN** the LLM calls `update_prompt` with `name: "Rust Code Review"` and `value: "You are a senior Rust engineer. Be extremely strict about unsafe blocks and panic sites."`
- **AND** the prompt "Rust Code Review" exists as a file-reference (`prompts/rust-code-review.json` → `prompts/rust-code-review.md`)
- **THEN** the system overwrites `prompts/rust-code-review.md` with the new text
- **AND** the system reloads configuration so the updated prompt takes effect immediately
- **AND** the tool returns a success message

#### Scenario: Update an inline prompt migrates to file-ref
- **WHEN** the LLM calls `update_prompt` with `name: "Code Helper"` and `value: "You are a coding assistant. Focus on security and performance."`
- **AND** the prompt "Code Helper" exists inline in `prompts/system_prompts.json`
- **THEN** the system creates `prompts/code-helper.md` with the new text
- **AND** the system creates `prompts/code-helper.json` with `{"Code Helper": {"value": ".\\code-helper.md"}}`
- **AND** the system removes the "Code Helper" entry from `prompts/system_prompts.json`
- **AND** the system reloads configuration

### Requirement: LLM can update a prompt's input template
The tool SHALL support updating the `input_template` field of an existing prompt without requiring the prompt text to be resent.

#### Scenario: Update input template only
- **WHEN** the LLM calls `update_prompt` with `name: "PR Description"` and `input_template: "Review changes from {source} to {target} in {repo}"`
- **AND** the prompt "PR Description" exists
- **THEN** the system updates the `input_template` in the prompt's JSON metadata to the new value
- **AND** the prompt's `value` (text) remains unchanged
- **AND** the system reloads configuration

#### Scenario: Update input template alongside value
- **WHEN** the LLM calls `update_prompt` with `name: "PR Description"`, `value: "You are a PR reviewer."`, and `input_template: "Review {repo}"`
- **AND** the prompt "PR Description" exists as a file-reference
- **THEN** the system updates both the `.md` file and the `input_template` in the JSON metadata
- **AND** the system reloads configuration

### Requirement: LLM can toggle a prompt's hidden state
The tool SHALL support updating the `hidden` field to show or hide a prompt from the UI menu.

#### Scenario: Hide a visible prompt
- **WHEN** the LLM calls `update_prompt` with `name: "Internal Helper"` and `hidden: true`
- **AND** the prompt "Internal Helper" exists and is currently visible
- **THEN** the system sets `hidden: true` in the prompt's JSON metadata
- **AND** the prompt no longer appears in the prompts menu after reload

#### Scenario: Unhide a hidden prompt
- **WHEN** the LLM calls `update_prompt` with `name: "Internal Helper"` and `hidden: false`
- **AND** the prompt "Internal Helper" exists and is currently hidden
- **THEN** the system sets `hidden: false` in the prompt's JSON metadata
- **AND** the prompt appears in the prompts menu after reload

### Requirement: LLM can rename a prompt
The tool SHALL support renaming a prompt via the `new_name` parameter. The old display name is replaced with the new one, the `.md` file is renamed to match the new sanitized name, and the JSON metadata is moved to a new file if the original JSON contained only that prompt.

#### Scenario: Rename a prompt with its own file pair
- **WHEN** the LLM calls `update_prompt` with `name: "Rust Code Review"` and `new_name: "Rust Code Reviewer"`
- **AND** the prompt "Rust Code Review" exists as `prompts/rust-code-review.json` + `prompts/rust-code-review.md`
- **THEN** the system creates `prompts/rust-code-reviewer.json` with `{"Rust Code Reviewer": {"value": ".\\rust-code-reviewer.md"}}`
- **AND** the system renames `rust-code-review.md` to `rust-code-reviewer.md`
- **AND** the system deletes the old `prompts/rust-code-review.json`
- **AND** the system reloads configuration

#### Scenario: Rename an inline prompt extracts it to its own files
- **WHEN** the LLM calls `update_prompt` with `name: "Code Helper"` and `new_name: "Code Assistant"`
- **AND** the prompt "Code Helper" exists inline in `prompts/system_prompts.json`
- **THEN** the system creates `prompts/code-assistant.json` with `{"Code Assistant": {"value": ".\\code-assistant.md"}}`
- **AND** the system creates `prompts/code-assistant.md` with the original prompt text
- **AND** the system removes the "Code Helper" entry from `prompts/system_prompts.json`
- **AND** the system reloads configuration

#### Scenario: Rename to a name that sanitizes to the same filename
- **WHEN** the LLM calls `update_prompt` with `name: "My Prompt"` and `new_name: "My Prompt!"`
- **AND** both sanitize to `my-prompt`
- **THEN** the system updates the display name in the JSON metadata from "My Prompt" to "My Prompt!"
- **AND** no files are renamed or moved
- **AND** the system reloads configuration

#### Scenario: Rename to a name whose sanitized filename already exists
- **WHEN** the LLM calls `update_prompt` with `name: "Rust Code Review"` and `new_name: "Rust Code"`
- **AND** `prompts/rust-code.json` already exists for a different prompt
- **THEN** the tool returns an error indicating the sanitized filename conflicts
- **AND** no files are modified

### Requirement: Prompt not found returns an error
The system SHALL return an error when the target prompt name does not exist in any prompt file.

#### Scenario: Update a non-existent prompt
- **WHEN** the LLM calls `update_prompt` with `name: "Nonexistent Prompt"`
- **AND** no prompt with that display name exists
- **THEN** the tool returns an error indicating the prompt was not found
- **AND** no files are modified

### Requirement: At least one update field must be provided
The tool SHALL require at least one of `new_name`, `value`, `input_template`, or `hidden` to be provided in the call.

#### Scenario: Call with no update fields
- **WHEN** the LLM calls `update_prompt` with only `name: "Rust Code Review"` and no other parameters
- **THEN** the tool returns an error indicating at least one update field is required

### Requirement: Tool always requires manual approval
The `update_prompt` tool SHALL NOT support auto-approval via regex patterns. Every tool call SHALL require manual user confirmation through the approval dialog.

#### Scenario: Update call triggers approval dialog
- **WHEN** the LLM calls `update_prompt` with valid parameters
- **THEN** the system shows the tool approval dialog to the user
- **AND** the tool call is only executed after the user approves

### Requirement: Tool definition is available for OpenAI and Gemini providers
The `PromptCreatorTool` class SHALL provide `GetOpenAiToolDefinition()` and `GetGeminiToolDefinition()` static methods that include both `create_prompt` and `update_prompt` in the returned tool arrays.

#### Scenario: OpenAI tool definitions include update_prompt
- **WHEN** `PromptCreatorTool.GetOpenAiToolDefinition()` is called
- **THEN** the returned array includes an entry with `function.name: "update_prompt"`
- **AND** the function definition includes `name` (required), `new_name`, `value`, `input_template`, and `hidden` parameters

#### Scenario: Gemini tool definitions include update_prompt
- **WHEN** `PromptCreatorTool.GetGeminiToolDefinition()` is called
- **THEN** the returned `functionDeclarations` array includes an entry with `name: "update_prompt"`

### Requirement: Configuration reloads after prompt update
The system SHALL call `ConfigurationService.GetInstance().Reload()` after successfully updating a prompt, so changes are immediately reflected in the UI.

#### Scenario: Updated prompt reflects in UI immediately
- **WHEN** the `update_prompt` tool successfully modifies a prompt
- **AND** `ConfigurationService.Reload()` is called
- **THEN** the updated prompt text, name, input template, and visibility are reflected in the UI without restarting the application

### Requirement: LLM knows which prompt is currently active
The system SHALL append the current system prompt's display name to the system message sent to the LLM, so the LLM can reference it by name when calling `update_prompt`.

#### Scenario: System message includes current prompt name
- **WHEN** the `LLMService` sends a request to the LLM
- **AND** the user has selected the "Rational" system prompt
- **THEN** the system message text ends with a line containing `Current prompt: "Rational"`
- **AND** this line appears after the date/time line

#### Scenario: Default prompt name is included
- **WHEN** the user has selected the default prompt (`_`)
- **THEN** the system message includes `Current prompt: "_"`

### Requirement: Tool parameters match the defined schema
The `update_prompt` tool SHALL accept `name` (string, required), `new_name` (string, optional), `value` (string, optional), `input_template` (string, optional), and `hidden` (boolean, optional). The tool SHALL reject calls with missing `name`.

#### Scenario: Missing name parameter
- **WHEN** the LLM calls `update_prompt` without the `name` parameter
- **THEN** the tool returns an error indicating that `name` is required

#### Scenario: name parameter is provided but empty
- **WHEN** the LLM calls `update_prompt` with `name: ""`
- **THEN** the tool returns an error indicating the name cannot be empty

### Requirement: Empty JSON files are cleaned up after rename or migration
When a rename or inline migration operation removes the last remaining prompt from a JSON file, the system SHALL delete the now-empty JSON file.

#### Scenario: system_prompts.json is not deleted when other prompts remain
- **WHEN** the LLM renames "Code Helper" (an inline prompt in `system_prompts.json`) to "Code Assistant"
- **AND** `system_prompts.json` still contains other prompts after removal
- **THEN** the system updates `system_prompts.json` in place without deleting it

#### Scenario: Standalone prompt JSON is deleted after rename
- **WHEN** the LLM renames "Rust Code Review" to "Rust Code Reviewer"
- **AND** `prompts/rust-code-review.json` contains only the "Rust Code Review" entry
- **THEN** the system deletes `prompts/rust-code-review.json` after creating the new files
