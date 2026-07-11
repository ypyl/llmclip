## ADDED Requirements

### Requirement: LLMService resolves tool definitions before providers
`LLMService.SendToLLM` SHALL expand the tool name list into tool definition objects using its `toolsMap` before passing settings to `LLMClient`, so providers receive resolved definitions rather than name strings.

#### Scenario: Tool names expanded to definitions
- **WHEN** `SendToLLM` is called with tool names `["execute_powershell", "web_search"]`
- **THEN** `settings["tools"]` SHALL contain the resolved definition objects from `PowerShellTool.GetOpenAiToolDefinition()` and `WebSearchTool.GetOpenAiToolDefinition()` in the same order

#### Scenario: Empty tool list
- **WHEN** no tools are enabled
- **THEN** `settings["tools"]` SHALL be an empty array

### Requirement: Providers use resolved tool definitions directly
Both `OpenAIProvider.GetRequestBody` and `OllamaProvider.GetRequestBody` SHALL assign `body["tools"]` directly from `settings["tools"]` without an `if-else` chain mapping names to definitions.

#### Scenario: OpenAI provider receives resolved definitions
- **WHEN** `OpenAIProvider.GetRequestBody` is called with `settings["tools"]` containing pre-resolved definition objects
- **THEN** the provider SHALL place those objects directly into `body["tools"]` without resolving tool names

#### Scenario: Ollama provider receives resolved definitions
- **WHEN** `OllamaProvider.GetRequestBody` is called with `settings["tools"]` containing pre-resolved definition objects
- **THEN** the provider SHALL place those objects directly into `body["tools"]` without resolving tool names
