## Context

See proposal.md — Why. The relevant mechanics: `SystemPrompts.Reload()` (services/Configuration/SystemPrompts.ahk) loops over every `prompts\*.json` file, merges all entries into one `prompts` map, and the map keys are the display names shown in the prompt selector (`GetSystemPromptNames` → prompt dropdown). A prompt's `value` may be inline text or a relative `.md` file reference (e.g. `.\\news.md`). The `prompts/` directory is gitignored and user-local; it is not part of the release zip.

## Goals / Non-Goals

**Goals:**
- Add exactly one new selectable prompt, keyed `absolute_mode`, visible in the existing prompt selector alongside the defaults.
- Keep the default `_` prompt and all existing prompts unchanged.
- Zero application code changes.

**Non-Goals:**
- No changes to the loader, selector, persistence, or any other app behavior (hence `skip_specs: true` — nothing the app does changes; a new prompt is data, not behavior).
- No changes to `roles.json`, `providers/`, or tool auto-approval config.

## Decisions

**D1: Single new JSON file `prompts/absolute_mode.json`, key `absolute_mode`.**
Follows the established pattern (one prompt per file is already used by `sample-test-prompt.json`, `auto_approve_example.json`). The map key is the exact name shown in the selector — the user asked for `absolute_mode`, so the key is `absolute_mode`, not "Absolute Mode".
*Alternative considered:* adding the entry to `system_prompts.json` — rejected; a dedicated file keeps user prompts separable from the shipped defaults and matches the existing multi-file convention.

**D2: Inline `value` text, not a `.md` file reference.**
The prompt is self-contained and short. `.md` references exist for long prompts (news, skill-generator, tool-generator); inline is simpler here and matches most existing entries.
*Alternative considered:* a `prompts/absolute_mode.md` file referenced via `".\\absolute_mode.md"` — unnecessary indirection for a prompt this size.

**D3: Prompt text encodes the mode's own rules (no filler, terminate after material, no engagement behaviors).**
The system prompt is written in the same blunt, directive register it demands, so the model's output style follows from the prompt's own form.

## Risks / Trade-offs

- [Prompt tone is subjective; the user may want to iterate on wording] → Prompt lives in the user-editable `prompts/` directory and can be edited via the app's built-in prompt editor or directly in the JSON; no code change needed to revise.
- [Some models may partially fall back to conversational habits] → The prompt explicitly enumerates the suppressed behaviors (engagement, sentiment uplift, continuation bias, tone mirroring) and mandates immediate termination after the material; this is the strongest lever available via system prompt alone.
