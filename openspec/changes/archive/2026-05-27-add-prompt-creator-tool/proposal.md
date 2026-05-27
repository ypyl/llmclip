## Why

Users can currently create and edit system prompts only by manually editing JSON files in the `prompts/` directory. There's no way to ask the LLM to create a new prompt conversationally. This change gives the LLM a tool to create prompts on demand, enabling a natural "make me a prompt that does X" workflow without leaving the chat interface.

## What Changes

- New `PromptCreatorTool` in `services/LLM/` — a tool the LLM can call to create new system prompts
- Tool writes prompt text to a `.md` file and creates a corresponding `.json` entry in `prompts/` (following the existing file-reference pattern used by prompts like "News" and "Skill Generator")
- Automatic reload of `ConfigurationService` after creation, so the new prompt appears in the UI immediately without restart
- Tool enablement wired through `LLMService.ConfigureToolSettings` alongside existing tools
- Auto-approval support via the existing regex pattern system (`tools.create_prompt.name`, `tools.create_prompt.value`)

## Capabilities

### New Capabilities
- `create-prompt-tool`: A new LLM-callable tool that creates system prompt files (`.md` text + `.json` metadata) in the `prompts/` directory, with duplicate detection and automatic configuration reload.

### Modified Capabilities
<!-- None - this is net-new functionality. No existing spec requirements change. -->

## Impact

- **New file**: `services/LLM/PromptCreatorTool.ahk` (tool class)
- **Modified**: `App.ahk` — `#Include` + instantiation + `toolsMap` registration
- **Modified**: `services/LLM/LLMService.ahk` — `ConfigureToolSettings` to add enable flag for new tool
- **Likely modified**: A controller or command for UI toggle of the new tool (if consistent with existing tool toggles)
- **No changes** to `SystemPrompts`, `ConfigurationService`, or `SessionManager` — existing reload and merge mechanisms already support this pattern
