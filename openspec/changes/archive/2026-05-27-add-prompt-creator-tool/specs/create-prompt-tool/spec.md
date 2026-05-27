## ADDED Requirements

### Requirement: LLM can create a new system prompt
The system SHALL provide a `create_prompt` tool that the LLM can call to create a new system prompt. The tool SHALL write the prompt text to a `.md` file and create a corresponding `.json` metadata file in the `prompts/` directory, following the existing file-reference pattern.

#### Scenario: Create a simple prompt
- **WHEN** the LLM calls `create_prompt` with `name: "Rust Code Review"` and `value: "You are a senior Rust engineer. Review code for safety and correctness."`
- **THEN** the system writes `prompts/rust-code-review.md` containing the value text
- **AND** the system writes `prompts/rust-code-review.json` containing `{"Rust Code Review": {"value": ".\\rust-code-review.md"}}`
- **AND** the system reloads configuration so the new prompt appears in the prompts menu
- **AND** the tool returns a success message indicating the prompt was created

#### Scenario: Create a prompt with input template
- **WHEN** the LLM calls `create_prompt` with `name: "PR Review"`, `value: "You are a code reviewer."`, and `input_template: "Review changes in {repo_path} from {source_branch} to {target_branch}"`
- **THEN** the system writes `prompts/pr-review.md` containing the value text
- **AND** the system writes `prompts/pr-review.json` containing `{"PR Review": {"value": ".\\pr-review.md", "input_template": "Review changes in {repo_path} from {source_branch} to {target_branch}"}}`

#### Scenario: Create a hidden prompt
- **WHEN** the LLM calls `create_prompt` with `name: "Internal Helper"`, `value: "You are an internal assistant."`, and `hidden: true`
- **THEN** the system writes the `.md` and `.json` files as usual
- **AND** the JSON includes `"hidden": true` so the prompt does not appear in the prompts menu

### Requirement: Duplicate prompt names are rejected
The system SHALL detect when a prompt with the same sanitized filename already exists and SHALL return an error without overwriting the existing prompt.

#### Scenario: Attempt to create a prompt that already exists
- **WHEN** the LLM calls `create_prompt` with `name: "Rust Code Review"`
- **AND** a file `prompts/rust-code-review.json` already exists
- **THEN** the tool returns an error message indicating the prompt already exists
- **AND** no files are modified

#### Scenario: Different display names that sanitize to the same filename
- **WHEN** the LLM calls `create_prompt` with `name: "My Prompt!"`
- **AND** the sanitized filename `my-prompt` collides with an existing `prompts/my-prompt.json` (from a different display name)
- **THEN** the tool returns an error indicating the prompt already exists

### Requirement: Prompt name is sanitized for filenames
The system SHALL derive a safe filename from the prompt display name by converting to lowercase and replacing non-alphanumeric characters with hyphens.

#### Scenario: Display name with spaces and special characters
- **WHEN** the display name is "API / SDK Guide!!!"
- **THEN** the sanitized filename is `api-sdk-guide`
- **AND** files are written as `prompts/api-sdk-guide.json` and `prompts/api-sdk-guide.md`

#### Scenario: Display name with leading and trailing characters
- **WHEN** the display name is "  Hello World  "
- **THEN** the sanitized filename is `hello-world`

### Requirement: Tool parameters match the defined schema
The `create_prompt` tool SHALL accept `name` (string, required), `value` (string, required), `input_template` (string, optional), and `hidden` (boolean, optional, default false). The tool SHALL reject calls with missing required parameters.

#### Scenario: Missing required parameter
- **WHEN** the LLM calls `create_prompt` without the `name` parameter
- **THEN** the tool returns an error indicating that `name` is required

#### Scenario: Missing value parameter
- **WHEN** the LLM calls `create_prompt` with `name: "Test"` but no `value`
- **THEN** the tool returns an error indicating that `value` is required

### Requirement: Tool definition is available for OpenAI and Gemini providers
The `PromptCreatorTool` class SHALL provide `GetOpenAiToolDefinition()` and `GetGeminiToolDefinition()` static methods that return the tool schema in the format expected by each LLM provider.

#### Scenario: OpenAI tool definition
- **WHEN** `PromptCreatorTool.GetOpenAiToolDefinition()` is called
- **THEN** it returns an object with `type: "function"` and `function.name: "create_prompt"`
- **AND** the function definition includes `name`, `value`, `input_template`, and `hidden` parameters

#### Scenario: Gemini tool definition
- **WHEN** `PromptCreatorTool.GetGeminiToolDefinition()` is called
- **THEN** it returns an object with a `functionDeclarations` array containing the same function definition

### Requirement: Configuration reloads after prompt creation
The system SHALL call `ConfigurationService.GetInstance().Reload()` after successfully creating a prompt, so the new prompt is immediately available in the UI without restarting the application.

#### Scenario: New prompt appears in UI after creation
- **WHEN** the `create_prompt` tool successfully writes a new prompt
- **AND** `ConfigurationService.Reload()` is called
- **THEN** the new prompt name appears in the system prompts menu in the UI

### Requirement: Tool supports auto-approval via regex patterns
The `create_prompt` tool SHALL integrate with the existing auto-approval system. Users MAY configure `tools.create_prompt.name` and `tools.create_prompt.value` regex patterns in prompt JSON files to auto-approve tool calls without manual confirmation.

#### Scenario: Auto-approval configured for a specific prompt
- **WHEN** a system prompt JSON includes `"tools.create_prompt.name": ".*"` and `"tools.create_prompt.value": ".*"`
- **AND** the LLM calls `create_prompt` while that system prompt is active
- **THEN** the tool call is executed without requiring manual user approval
