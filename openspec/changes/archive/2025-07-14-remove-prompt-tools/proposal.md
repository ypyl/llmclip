## Why

The `create_prompt` and `update_prompt` LLM tools proved unsuccessful — they are unintuitive for the LLM to invoke correctly and hard for users to rely on. Removing them simplifies the codebase, reduces the tool roster, and eliminates dead UX that nobody uses.

## What Changes

- **Delete** `services/LLM/PromptCreatorTool.ahk` — the entire tool implementation (both `create_prompt` and `update_prompt`)
- **Remove** `#Include`, instantiation, and wiring from `App.ahk` (tool map entries, tool definition entries)
- **Remove** `createPromptEnabled` / `updatePromptEnabled` parameters from `LLMService.ConfigureToolSettings()` and `SendToLLM()`
- **Remove** tool enablement checks from `SendToLLMCommand.Execute()`
- **Remove** PromptCreatorTool branches from `ExecuteToolCallsCommand.MatchesPattern()`
- **Remove** `#Include` and PromptCreatorTool branches from `GoogleProvider.ahk`
- **Remove** specs: `openspec/specs/create-prompt-tool/spec.md` and `openspec/specs/update-prompt-tool/spec.md`

## Capabilities

### Modified Capabilities
- `create-prompt-tool`: **REMOVED** — the entire capability is removed
- `update-prompt-tool`: **REMOVED** — the entire capability is removed

## Impact

- **Deleted**: `services/LLM/PromptCreatorTool.ahk`
- **Modified**: `App.ahk`, `services/LLM/LLMService.ahk`, `commands/SendToLLMCommand.ahk`, `commands/ExecuteToolCallsCommand.ahk`, `services/LLM/Providers/GoogleProvider.ahk`
- **Deleted specs**: `openspec/specs/create-prompt-tool/`, `openspec/specs/update-prompt-tool/`
- **No breaking changes** to other tools or the tool execution pipeline — the remaining 5 tools (PowerShell, FileSystem, WebSearch, WebFetch, MarkdownNew) are unaffected
