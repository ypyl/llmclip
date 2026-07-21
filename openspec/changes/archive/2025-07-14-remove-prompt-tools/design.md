## Context

The `PromptCreatorTool` implements two LLM-callable tools: `create_prompt` and `update_prompt`. Both use the same class with a `toolName` constructor parameter. They are the only tools in the system that modify prompt files on disk.

The tools are wired through the standard tool pipeline: `App.ahk` instantiates two instances (`pct` and `pcu`), adds them to the `toolsMap`, and includes them in `toolDefs` for the Tools menu. `LLMService.ConfigureToolSettings()` conditionally enables them based on user preferences. `GoogleProvider` has special handling because Gemini uses a different tool definition format.

## Goals / Non-Goals

**Goals:**
- Remove the `PromptCreatorTool` class and all its references
- Clean up the tool pipeline so `create_prompt` / `update_prompt` are no longer available as tools
- Remove the corresponding main specs

**Non-Goals:**
- Removing `SystemPrompts.UpdatePrompt()` — this is internal infrastructure, not a user-facing tool. It stays as dead code that could be reused later.
- Changing the `promptName` injection in `LLMService.SendToLLM()` — this is unrelated (it tells the LLM which prompt is active)
- Removing `SystemPrompts.SanitizeFileName()` — it has its own copy, independent of PromptCreatorTool

## Decisions

### Decision 1: Delete the tool file entirely

**Chosen**: Delete `services/LLM/PromptCreatorTool.ahk`. Both `create_prompt` and `update_prompt` are unused and unwanted.

**Alternative**: Keep the file but stop registering it. Rejected — dead code rots.

### Decision 2: Remove tool params from LLMService signatures

**Chosen**: Remove `createPromptEnabled` and `updatePromptEnabled` from both `ConfigureToolSettings()` and `SendToLLM()`. This is a breaking change to those method signatures, but they are internal — no external callers exist outside `SendToLLMCommand`.

### Decision 3: Remove specs rather than mark as REMOVED delta

**Chosen**: Delta specs under `specs/create-prompt-tool/spec.md` and `specs/update-prompt-tool/spec.md` will contain `## REMOVED Requirements` blocks. On archive sync, the main spec files will be deleted since all requirements are removed.

## Risks / Trade-offs

- **Regret**: If the tools are wanted again later, they can be restored from git history. The specs in the archive preserve the original requirements.
- **Tool menu gap**: The Tools menu will shrink from 7 entries to 5. This is acceptable — a smaller, higher-quality tool roster is better than a bloated one.
