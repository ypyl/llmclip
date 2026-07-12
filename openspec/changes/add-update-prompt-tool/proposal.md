## Why

The LLM can create new system prompts via `create_prompt`, but it cannot modify existing ones. When a user says "improve my Rust Code Review prompt to also check for unsafe blocks," the LLM hits a wall — `create_prompt` rejects duplicate names. Users must manually edit prompt files or use the UI editor. This gap breaks the natural conversational flow of prompt iteration.

## What Changes

- New `update_prompt` LLM-callable tool that modifies existing system prompts (text, input template, visibility, and display name)
- Inline prompts (stored directly in `system_prompts.json`) are migrated to the file-reference pattern (`.md` + `.json` pair) on update, ensuring a consistent output format
- The current system prompt name is appended to the system message so the LLM knows which prompt it's operating on
- `update_prompt` always requires manual user approval — no auto-approval regex support
- Rename support: `new_name` parameter creates a new file pair and cleans up the old files

## Capabilities

### New Capabilities

- `update-prompt-tool`: LLM-callable tool to update existing system prompt properties (value, input_template, hidden, display name), migrate inline prompts to file-ref format, and reload configuration after changes.

### Modified Capabilities

- `create-prompt-tool`: No requirement changes. The `create_prompt` tool retains its existing behavior (create-only, error on duplicate). The system message format gains a "Current prompt:" prefix — this is implementation detail, not a spec-level behavior change to the create tool itself.

## Impact

- **Service layer**: `PromptCreatorTool.ahk` — new tool definition and execute branch; `SystemPrompts.ahk` — new generic update method; `LLMService.ahk` — system message format change, new tool enable flag
- **Command layer**: `SendToLLMCommand.ahk` — wire `updatePromptEnabled` flag; `ExecuteToolCallsCommand.ahk` — auto-approval chain entry
- **Composition root**: `App.ahk` — tool registration in `toolsMap` and `toolDefs`
- No new files. No changes to `Lib/`, `ui/`, `controllers/`, or `ConfigurationService`.
