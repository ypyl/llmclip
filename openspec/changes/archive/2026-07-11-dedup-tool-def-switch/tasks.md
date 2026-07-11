## 1. LLMService — expand tool definitions before provider handoff

- [x] 1.1 In `LLMService.SendToLLM`, after the `settings["tools"] := this.ConfigureToolSettings(...)` line, add a loop that replaces the name array with expanded definition objects: `for t in settings["tools"]` → `this.tools[t].GetOpenAiToolDefinition()`

## 2. OpenAIProvider — remove duplicate switch

- [x] 2.1 In `OpenAIProvider.GetRequestBody`, replace the 12-line `if-else` chain (lines 26-41) with `body["tools"] := settings["tools"]`
- [x] 2.2 Remove the 6 `#Include` lines for tool class files (PowerShellTool, FileSystemTool, WebSearchTool, WebFetchTool, MarkdownNewTool, PromptCreatorTool) from the top of `OpenAIProvider.ahk`

## 3. OllamaProvider — remove duplicate switch

- [x] 3.1 In `OllamaProvider.GetRequestBody`, replace the identical 12-line `if-else` chain with `body["tools"] := settings["tools"]`
- [x] 3.2 Remove the 6 `#Include` lines for tool class files from the top of `OllamaProvider.ahk`

## 4. Integration check

- [x] 4.1 Run `main.ahk`, enable at least one tool, send a message to an LLM that supports tools — verify tool definitions reach the API (check no error, tool call works if the model returns one)
