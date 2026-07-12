## 1. Service: SystemPrompts — generic update method

- [x] 1.1 Add `UpdatePrompt(name, updates)` method to `SystemPrompts` class that: loops through all `prompts/*.json` files to find the prompt by display name; applies provided fields (`new_name`, `value`, `input_template`, `hidden`) to the parsed JSON; handles inline→file-ref migration when `value` changes; handles rename via `new_name` (creates new file pair, removes old entry, cleans up empty JSON files); returns result with error/success details
- [x] 1.2 Verify `UpdatePrompt` by running `main.ahk` (deferred to integration phase) and calling it programmatically (or via a quick inline test in `App.ahk` startup) with a test prompt

## 2. Service: PromptCreatorTool — update_prompt tool

- [x] 2.1 Add static constants `TOOL_NAME_UPDATE := "update_prompt"` and `TOOL_LABEL_UPDATE := "Update Prompt"`
- [x] 2.2 Add `GetOpenAiToolDefinition()` support for `update_prompt` (instance dispatches by tool role via constructor parameter `toolName`; returns `update_prompt` schema when instantiated with `TOOL_NAME_UPDATE`)
- [x] 2.3 Add `GetGeminiUpdateToolDefinition()` static method returning the Gemini-formatted `update_prompt` schema
- [x] 2.4 Add `ExecuteUpdatePrompt(toolCall)` method: validates `name` is required and non-empty; validates at least one of `new_name`, `value`, `input_template`, `hidden` is provided; delegates to `SystemPrompts.UpdatePrompt()`; returns success/error tool response
- [x] 2.5 Update `ExecuteToolCall(toolCall)` to dispatch to `ExecuteUpdatePrompt` when `toolCall.Name == TOOL_NAME_UPDATE`
- [x] 2.6 Test by running `main.ahk` with `update_prompt` enabled — verify tool appears in tools menu

## 3. Service: LLMService — system message and tool enablement

- [x] 3.1 In `SendToLLM()`, append `Current prompt: "<name>"` line after the date/time line in the system message. The prompt name comes from the active session's prompt name.
- [x] 3.2 Add `updatePromptEnabled` parameter to `ConfigureToolSettings()`, appending `PromptCreatorTool.TOOL_NAME_UPDATE` to `enabledTools` when true
- [x] 3.3 In the tool definition resolution loop, handle `PromptCreatorTool` instances returning `update_prompt` definitions (each instance returns the definition for the tool name it was constructed with)

## 4. Composition root: App.ahk — registration

- [x] 4.1 Instantiate a second `PromptCreatorTool` instance for `update_prompt`: `pcu := PromptCreatorTool(PromptCreatorTool.TOOL_NAME_UPDATE)`
- [x] 4.2 Add `PromptCreatorTool.TOOL_NAME_UPDATE, pcu` to `toolsMap`
- [x] 4.3 Add `{ id: PromptCreatorTool.TOOL_NAME_UPDATE, label: PromptCreatorTool.TOOL_LABEL_UPDATE }` to `toolDefs`

## 5. Command: SendToLLMCommand — wire enable flag

- [x] 5.1 Read `updatePromptEnabled` from `configManager.IsToolEnabled(modelIndex, PromptCreatorTool.TOOL_NAME_UPDATE)`
- [x] 5.2 Pass `updatePromptEnabled` through to `LLMService.SendToLLM()` and `LLMService.ConfigureToolSettings()`

## 6. Command: ExecuteToolCallsCommand — auto-approval chain

- [x] 6.1 Add `PromptCreatorTool.TOOL_NAME_UPDATE` to the auto-approval chain with a `patternKey` entry that always returns `false` (no auto-approval for `update_prompt` — every call requires manual confirmation)

## 7. Provider: GoogleProvider — Gemini tool registration

- [x] 7.1 Add `PromptCreatorTool.GetGeminiUpdateToolDefinition()` call in the Gemini tool resolution block (alongside the existing `PromptCreatorTool.GetGeminiToolDefinition()`)

## 8. Integration & verification

- [x] 8.1 Run `main.ahk`, enable `Update Prompt` tool for the active model
- [x] 8.2 Send a chat message: "update the current prompt to end every response with 'Stay curious.'" — verify LLM calls `update_prompt` with the current prompt name, approval dialog appears, prompt text updates, new text takes effect on next message
- [x] 8.3 Test rename: "rename the current prompt to 'Curious Assistant'" — verify new file pair created, old cleaned up, prompt appears under new name in menu
- [x] 8.4 Test inline migration: select an inline prompt (e.g., "Code Helper"), ask LLM to update its text — verify it gets extracted to standalone file pair
- [x] 8.5 Test partial update: update only `hidden` or `input_template` without changing text — verify only that field changes
- [x] 8.6 Test error cases: update non-existent prompt → error; update with empty name → error; update with no fields → error; update to name whose filename collides → error
