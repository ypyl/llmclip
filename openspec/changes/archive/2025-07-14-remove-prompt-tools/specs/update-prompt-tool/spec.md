## REMOVED Requirements

### Requirement: LLM can update an existing system prompt's text
**Reason**: The `update_prompt` tool proved unintuitive for LLMs to use correctly and was not used by users.
**Migration**: None. Users edit prompts manually in the `prompts/` directory or via the UI.

### Requirement: LLM can update a prompt's input template
**Reason**: Removed with the `update_prompt` tool.
**Migration**: None.

### Requirement: LLM can toggle a prompt's hidden state
**Reason**: Removed with the `update_prompt` tool.
**Migration**: None.

### Requirement: LLM can rename a prompt
**Reason**: Removed with the `update_prompt` tool.
**Migration**: None.

### Requirement: Prompt not found returns an error
**Reason**: Removed with the `update_prompt` tool.
**Migration**: None.

### Requirement: At least one update field must be provided
**Reason**: Removed with the `update_prompt` tool.
**Migration**: None.

### Requirement: Tool always requires manual approval
**Reason**: Removed with the `update_prompt` tool.
**Migration**: None.

### Requirement: Tool definition is available for OpenAI and Gemini providers
**Reason**: Removed with the `update_prompt` tool.
**Migration**: None.

### Requirement: Configuration reloads after prompt update
**Reason**: Removed with the `update_prompt` tool.
**Migration**: None.

### Requirement: LLM knows which prompt is currently active
**Reason**: This requirement is independent of the `update_prompt` tool — the `promptName` injection in `LLMService.SendToLLM()` is NOT being removed. The requirement remains implemented; only the spec artifact is removed with the rest of the capability.
**Migration**: The behavior persists. If a replacement spec is needed in the future, document the `promptName` injection separately.

### Requirement: Tool parameters match the defined schema
**Reason**: Removed with the `update_prompt` tool.
**Migration**: None.

### Requirement: Empty JSON files are cleaned up after rename or migration
**Reason**: Removed with the `update_prompt` tool.
**Migration**: None.
