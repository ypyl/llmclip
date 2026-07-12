## Context

The `create_prompt` tool (archived change `2026-05-27-add-prompt-creator-tool`) lets the LLM create new system prompts as `.md` + `.json` file pairs. It refuses to overwrite existing prompts. The codebase also has internal prompt-update machinery (`SystemPrompts.UpdatePromptValue`, `ConfigurationService.SaveRawSystemPromptValue`) but none of it is exposed to the LLM.

Users want conversational prompt iteration: "improve my Rust Code Review prompt" → LLM silently updates it. Currently the LLM has no way to do this.

Prompts live in two storage forms:
- **File-ref**: JSON has `"value": ".\\foo.md"` — text in separate `.md` file (what `create_prompt` produces)
- **Inline**: JSON has `"value": "actual text..."` — text embedded in JSON (legacy, `system_prompts.json`)

## Goals / Non-Goals

**Goals:**
- Let the LLM update an existing prompt's text (`value`), input template, hidden state, and display name
- Migrate inline prompts to file-ref format on any update that touches `value`
- Always require manual user approval (no auto-approval regex)
- Let the LLM know which prompt is active by appending its name to the system message
- Follow existing tool conventions exactly (same class file, same registration pattern)
- Support rename: move to new file pair, clean up old one

**Non-Goals:**
- Deleting prompts
- Listing all prompts (LLM discovers via conversation context)
- Updating auto-approval regex patterns on prompts
- New files — everything lives in `PromptCreatorTool.ahk` and `SystemPrompts.ahk`
- Changes to `create_prompt` behavior (still create-only, still rejects duplicates)

## Decisions

### D1: Separate tool — `update_prompt`, not upsert on `create_prompt`

`create_prompt` stays create-only with duplicate rejection (preserving its safety contract). `update_prompt` is a new tool in the same class file.

Alternatives considered:
- **Upsert `create_prompt`**: Fewer lines, but silently overwrites. Reverses D4 of the original design, which explicitly chose error-on-duplicate as a safety guard. Rejected.
- **`action` parameter on `create_prompt`**: Overloads semantics, harder for LLM to reason about. Two clean tools are better than one muddled one.

### D2: Inline prompts migrate to file-ref on update

When updating a prompt stored inline in `system_prompts.json`, the tool:
1. Creates a `.md` file with the prompt text
2. Creates a `.json` file referencing it
3. Removes the entry from the original JSON file
4. If the original JSON file is now empty → deletes it

This ensures a consistent output format. Every prompt touched by the tool ends up as a standalone file pair.

Alternative considered: update inline in-place. Rejected — keeping two code paths for write-back adds complexity. Migrate once, never worry about it again.

### D3: Rename always extracts to standalone file pair

When `new_name` is provided, the tool creates a new `.json` + `.md` pair for the new name, copies/renames the `.md` file, and removes the old entry. If the old prompt was inline in a multi-prompt JSON, it's removed from there. If the old prompt had its own file pair, the old files are deleted after migration.

Edge case: new name sanitizes to same filename as old name → no-op on files, only the JSON display name changes. Edge case: new name sanitizes to a filename that already exists (different display name) → error.

### D4: System message includes current prompt name

`LLMService.SendToLLM()` appends `Current prompt: "<name>"` below the date/time line in the system message. This is one line, `FormatTime`-adjacent. Costs nothing, lets the LLM reference the prompt by name.

Format:
```
<system prompt text>

Current Date and Time: 2026-07-12 14:30:00
Current prompt: "Rational"
```

### D5: No auto-approval for `update_prompt`

The tool has no `tools.update_prompt.*` regex keys. Every call triggers the manual approval dialog. This is safer for mutation of existing configuration. The `ExecuteToolCallsCommand` auto-approval chain adds an entry that always returns `false` for `update_prompt`, or simply omits the auto-approval path entirely.

Alternative considered: same auto-approval pattern as `create_prompt`. Rejected — updating is higher stakes than creating. Users should always review.

### D6: `new_name` is optional; at least one update field required

The tool requires at least one of `new_name`, `value`, `input_template`, or `hidden` to be provided. If none are, it returns an error. This prevents no-op calls.

### D7: Generic `UpdatePrompt` method on `SystemPrompts`

Rather than adding multiple field-specific methods, a single `UpdatePrompt(name, updates)` method handles arbitrary partial updates. It:
1. Loops through all `prompts/*.json` files to find the prompt
2. Applies each provided field to the parsed JSON
3. If `value` changed and is file-ref → overwrites the `.md` file
4. Dumps the modified JSON back to disk
5. Updates the in-memory cache

This is a cleaner extension point than adding `UpdatePromptInputTemplate`, `UpdatePromptHidden`, etc. individually.

### D8: Tool enablement — same pattern as `create_prompt`

A new `updatePromptEnabled` parameter flows through `LLMService.ConfigureToolSettings()` → `SendToLLMCommand` → wire the flag. The tool toggle appears in the tools menu alongside `create_prompt`.

## Risks / Trade-offs

- **[Inline → file-ref migration messes with hand-edited JSON]** — If a user hand-edits `system_prompts.json` and the LLM later updates a prompt, it gets extracted out. Mitigation: This is consistent and predictable behavior. The user can always move it back manually. The alternative (two write-back code paths) is worse.

- **[Rename + value update in one call can fail halfway]** — If `value` write succeeds but rename's file move fails, the prompt is in a mixed state. Mitigation: Validate new filename before any writes. Write new files first, delete old files last. If deletion fails, data is at worst duplicated (safe). Error message surfaces the partial state.

- **[Empty JSON file cleanup might delete user's file]** — If a user has a `custom.json` with only one prompt and that prompt gets renamed/migrated out, the tool deletes the now-empty file. Mitigation: This follows the `create_prompt` pattern (one prompt per file pair). The file served no purpose once empty. If the user wants to keep it, they should add another prompt to it.

- **[Concurrent access not handled]** — If user is editing a prompt file while LLM calls `update_prompt`, writes could interleave. Mitigation: Extremely unlikely in practice (single-user desktop app, LLM calls are serialized). Not worth a file-locking mechanism for V1.

## Open Questions

None — all design decisions resolved above.
