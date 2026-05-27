## Context

The LLMClip prompt system stores system prompts as JSON files in `prompts/`. Each prompt entry maps a display name to a config with:
- `value`: Either inline text or a file path like `".\\my-prompt.md"` — the actual system prompt text
- `input_template` (optional): Template with `{placeholders}` for user input
- `hidden` (optional): Whether to hide from the prompts menu
- `tools.<Tool>.<param>` (optional): Auto-approval regex patterns

`SystemPrompts` loads and merges all `*.json` files at startup. `ConfigurationService.Reload()` triggers a full reload. Currently, prompts can only be created/edited by manually editing files or through the UI's raw text editor for existing prompts.

The LLM already has access to a generic `FileSystemTool` that can write arbitrary files, but it has no prompt awareness — no validation, no reload trigger, and the LLM must craft exact JSON format.

The existing tool architecture (see `WebFetchTool`, `FileSystemTool`, etc.) uses:
- `static TOOL_NAME` constant
- `GetOpenAiToolDefinition()` / `GetGeminiToolDefinition()` static methods returning tool schemas
- `ExecuteToolCall(toolCall)` instance method for dispatch
- Registration in `App.ahk` → `toolsMap` → `LLMService`

## Goals / Non-Goals

**Goals:**
- Let the LLM create new system prompts via a dedicated tool call
- Write prompt text to a `.md` file and metadata to a corresponding `.json` file (following the existing file-reference pattern)
- Detect duplicate prompt names and return clear errors
- Trigger `ConfigurationService.Reload()` after successful creation so the new prompt appears in the UI immediately
- Support auto-approval via the existing regex pattern system
- Follow existing tool conventions exactly (no new patterns)

**Non-Goals:**
- Editing existing prompts (already supported via UI)
- Deleting prompts
- Listing prompts before creation
- Inline `value` storage (always `.md` file reference)
- Setting auto-approval patterns on newly created prompts (V1 limitation)
- Any changes to `SystemPrompts`, `ConfigurationService`, or `SessionManager`

## Decisions

### D1: Tool name — `create_prompt`
Chose `create_prompt` over alternatives (`prompt_create`, `save_prompt`). Rationale: follows the verb-first convention of existing tools (`web_fetch`, `web_search`, `file_system` uses noun but is an outlier). `create` is clearer than `save` for the "new only, no overwrite" semantics. The TOOL_NAME constant is `create_prompt`, class name is `PromptCreatorTool`.

### D2: File naming — sanitize display name to kebab-case
"Rust Code Review" → `rust-code-review.json` + `rust-code-review.md`. Sanitization: lowercase, replace non-alphanumeric with hyphens, collapse multiple hyphens, trim. This is deterministic — the same display name always produces the same filename. The LLM does not control filenames; it only provides the display name. The tool derives the sanitized filename internally.

Alternative considered: Let the LLM specify the filename. Rejected — adds unnecessary complexity and risk of bad filenames.

### D3: Output format — one JSON + one MD file per prompt
Each new prompt gets its own pair of files:
- `prompts/<sanitized>.md` — the actual system prompt text
- `prompts/<sanitized>.json` — metadata referencing the `.md`:
  ```json
  { "<Display Name>": { "value": ".\\<sanitized>.md" } }
  ```

This follows the exact pattern used by "News" (`news.json` → `news.md`), "Skill Generator", and "Tools Record". Alternative considered: appending to `system_prompts.json`. Rejected — individual files are simpler to create (no read-modify-write), easier to manage, and consistent with existing multi-file prompts.

### D4: Duplicate detection — error on filename collision
The tool checks if `<sanitized>.json` already exists in `prompts/`. If yes, returns an error. No overwrite. The LLM receives the error and can inform the user. This is simpler and safer than an overwrite flag. If the user wants a prompt with a similar name, they pick a different display name.

### D5: Reload strategy — call `ConfigurationService.GetInstance().Reload()`
After writing both files, the tool calls the singleton's `Reload()`. This re-reads all `prompts/*.json` files and refreshes the UI's prompt list. No restart needed. The tool does NOT need `SystemPrompts` injected — it just writes files and triggers reload through the singleton.

### D6: Constructor — no dependencies
All existing tools (`FileSystemTool`, `PowerShellTool`, etc.) are instantiated with zero constructor args in `App.ahk`. `PromptCreatorTool` follows this pattern. It accesses `ConfigurationService.GetInstance()` internally. No constructor injection needed.

### D7: Auto-approval support
The tool parameters map to auto-approval keys:
- `tools.create_prompt.name` — regex for the prompt display name
- `tools.create_prompt.value` — regex for the prompt text content

This follows the existing pattern documented in `TOOL_AUTO_APPROVAL.md`. No special handling needed in the tool itself — the auto-approval check happens in the controller layer before the tool executes.

### D8: Tool enablement — consistent with existing toggle pattern
The tool enable flag is added to `LLMService.ConfigureToolSettings()` alongside `fileSystemEnabled`, `webSearchEnabled`, etc. A new `createPromptEnabled` parameter. This means the tool can be toggled per model in settings.

## Risks / Trade-offs

- **[Duplicate sanitized names]** — Two different display names could sanitize to the same filename (e.g., "My Prompt!" and "My Prompt??" both → `my-prompt`). Mitigation: The tool detects the file collision and returns an error. The user picks a different display name. In practice, this is rare and acceptable.

- **[Reload side effects]** — `ConfigurationService.Reload()` reloads providers, roles, AND prompts. If another part of the system is mid-operation during reload, state could be inconsistent. Mitigation: Prompt creation typically happens between LLM interactions when nothing else is in flight. The existing "Reload Settings" button already does full reloads without issues.

- **[LLM writes poor prompts]** — The LLM might create low-quality or nonsensical prompts. Mitigation: The user can always delete the files manually or edit the prompt. The tool requires approval by default (auto-approval must be explicitly configured). This is no different from the LLM generating poor code or text in any chat.

- **[No prompt validation]** — The tool doesn't validate that the prompt text is well-formed (e.g., doesn't check for contradictory instructions). Mitigation: This is a V1 scope decision. The LLM is the prompt creator; validating its own output is the LLM's job. The user reviews the result.

- **[C++ and special characters in display names]** — Filename sanitization for edge cases like "C++ Tips" (becomes `c-tips` which loses meaning) or Unicode names. Mitigation: Acceptable for V1. The display name in the JSON key is preserved unchanged; only the filename is sanitized.
