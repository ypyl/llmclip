## REMOVED Requirements

### Requirement: LLM can create a new system prompt
**Reason**: The `create_prompt` tool proved unintuitive for LLMs to use correctly and was not used by users.
**Migration**: None. Users create and edit prompts manually in the `prompts/` directory or via the UI.

### Requirement: Duplicate prompt names are rejected
**Reason**: Removed with the `create_prompt` tool.
**Migration**: None.

### Requirement: Prompt name is sanitized for filenames
**Reason**: Removed with the `create_prompt` tool. `SystemPrompts.SanitizeFileName()` remains available for internal use.
**Migration**: None.

### Requirement: Tool parameters match the defined schema
**Reason**: Removed with the `create_prompt` tool.
**Migration**: None.

### Requirement: Tool definition is available for OpenAI and Gemini providers
**Reason**: Removed with the `create_prompt` tool.
**Migration**: None.

### Requirement: Configuration reloads after prompt creation
**Reason**: Removed with the `create_prompt` tool.
**Migration**: None.

### Requirement: Tool supports auto-approval via regex patterns
**Reason**: Removed with the `create_prompt` tool.
**Migration**: None.
