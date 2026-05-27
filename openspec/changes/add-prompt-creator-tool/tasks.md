## 1. Create the PromptCreatorTool service

- [x] 1.1 Create `services/LLM/PromptCreatorTool.ahk` with class `PromptCreatorTool`, static `TOOL_NAME := "create_prompt"`, and `ExecuteToolCall(toolCall)` method that validates parameters, sanitizes the display name to a kebab-case filename, checks for existing files, writes `.md` and `.json` files to `prompts/`, calls `ConfigurationService.GetInstance().Reload()`, and returns a `ChatMessage` with success/error result
- [x] 1.2 Implement `GetOpenAiToolDefinition()` static method returning the OpenAI-format tool schema with `name`, `value` (required), `input_template` (optional), and `hidden` (optional, default false) parameters
- [x] 1.3 Implement `GetGeminiToolDefinition()` static method returning the Gemini-format tool schema (wrapped in `functionDeclarations` array)

## 2. Wire up in App.ahk (composition root)

- [x] 2.1 Add `#Include Services\LLM\PromptCreatorTool.ahk` to the include list in `App.ahk`
- [x] 2.2 Instantiate `PromptCreatorTool()` in `App.ahk` alongside other tool instantiations
- [x] 2.3 Add `PromptCreatorTool.TOOL_NAME, pct` entry to the `toolsMap` in `App.ahk`

## 3. Wire up tool enablement

- [x] 3.1 Add `createPromptEnabled` parameter to `LLMService.ConfigureToolSettings()` method
- [x] 3.2 In `ConfigureToolSettings`, add logic: if `createPromptEnabled`, push `PromptCreatorTool.TOOL_NAME` to `enabledTools`
- [x] 3.3 Add `create_prompt: this.configManager.IsToolEnabled(...)` entry to `GetToolsMenuStateCommand.Execute()` return map

## 4. Pass enable flag through the call chain

- [x] 4.1 Add `createPromptEnabled` parameter to `LLMService.SendToLLM()` method
- [x] 4.2 Pass `createPromptEnabled` through from `SendToLLM` to `ConfigureToolSettings`
- [x] 4.3 Trace the `SendToLLM` call site(s) in controllers/commands and ensure the new parameter is passed (likely defaulting to `false` if not explicitly available from UI state)
- [x] 4.4 Add `PromptCreatorTool` entry to `MenuView.ToolMapping` static array so the tool appears in the Tools menu
- [x] 4.5 Add `#Include` and tool schema mapping for `PromptCreatorTool` in `OpenAIProvider.ahk`, `OllamaProvider.ahk`, and `GoogleProvider.ahk` (the hardcoded if-else chains that resolve TOOL_NAME strings → tool definitions)
- [x] 4.6 Add prompt dropdown auto-refresh after LLM interactions in `MainController.AskToLLM()` so newly created prompts appear in the dropdown without manual reload

## 5. Integration test

- [ ] 5.1 Run `main.ahk`, enable the `create_prompt` tool in settings, start a chat, and ask the LLM: "Create a system prompt called 'Test Prompt' that acts as a git helper." Verify `prompts/test-prompt.md` and `prompts/test-prompt.json` are created, the prompt appears in the prompts menu, and the LLM confirms the creation in its response
- [ ] 5.2 Test duplicate detection: ask the LLM to create "Test Prompt" again and verify the tool returns an error
- [ ] 5.3 Test auto-approval: configure `tools.create_prompt.name: ".*"` in a prompt JSON, use that prompt, and verify the tool executes without the approval dialog
