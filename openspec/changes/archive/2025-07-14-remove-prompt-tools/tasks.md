## 1. Delete the tool file

- [x] 1.1 Delete `services/LLM/PromptCreatorTool.ahk`

## 2. Clean up App.ahk

- [x] 2.1 Remove `#Include Services\LLM\PromptCreatorTool.ahk` from `App.ahk`
- [x] 2.2 Remove `pct` and `pcu` instantiation lines
- [x] 2.3 Remove `PromptCreatorTool.TOOL_NAME` and `TOOL_NAME_UPDATE` entries from `toolsMap`
- [x] 2.4 Remove `PromptCreatorTool.TOOL_NAME` and `TOOL_NAME_UPDATE` entries from `toolDefs`

## 3. Clean up LLMService

- [x] 3.1 Remove `createPromptEnabled` and `updatePromptEnabled` parameters from `ConfigureToolSettings()` and the tool-pushing logic for both
- [x] 3.2 Remove `createPromptEnabled` and `updatePromptEnabled` parameters from `SendToLLM()` signature and the call to `ConfigureToolSettings`

## 4. Clean up SendToLLMCommand

- [x] 4.1 Remove the `createPromptEnabled` and `updatePromptEnabled` variable assignments and their `IsToolEnabled` checks
- [x] 4.2 Remove the two parameters from the call to `llmService.SendToLLM()`

## 5. Clean up ExecuteToolCallsCommand

- [x] 5.1 Remove the `PromptCreatorTool.TOOL_NAME` and `TOOL_NAME_UPDATE` branches from `MatchesPattern()`

## 6. Clean up GoogleProvider

- [x] 6.1 Remove `#Include "..\PromptCreatorTool.ahk"` from `services/LLM/Providers/GoogleProvider.ahk`
- [x] 6.2 Remove the `PromptCreatorTool.TOOL_NAME` and `TOOL_NAME_UPDATE` branches from tool definition loop

## 7. Integration verification

- [x] 7.1 Run `main.ahk`, verify the Tools menu no longer shows "Create Prompt" and "Update Prompt" *(manual verification)*
- [x] 7.2 Send a message to LLM, verify the 5 remaining tools still function correctly *(manual verification)*
