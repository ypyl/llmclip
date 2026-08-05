## Why

The user wants a system prompt that eliminates all conversational filler — emojis, hype, soft asks, transitions, and closing appendixes — and speaks bluntly to the user's underlying cognitive tier. This mode is intended for high-fidelity work where the assistant's value is the material it delivers, not the tone it wraps it in.

## What Changes

- Add a new selectable system prompt named `absolute_mode` in the `prompts/` directory (`prompts/absolute_mode.json`).
- The prompt enforces: no emojis, filler, hype, soft asks, conversational transitions, or call-to-action appendixes; no mirroring of the user's diction/mood/affect; no questions, offers, suggestions, or motivational content; replies terminate immediately after the requested material; all engagement/continuation-bias behaviors suppressed.
- No application code changes. The existing loader (`SystemPrompts.Reload()`) already merges every JSON file in `prompts/` and the UI already lists every key in the prompt selector.
- The default `_` prompt is untouched.

## Capabilities

### New Capabilities

None. This is a pure content/config addition — no application behavior changes. The prompt loader and selector already support arbitrary prompts in `prompts/`.

### Modified Capabilities

None.

> Opt-out: `skip_specs: true` is set in `.openspec.yaml` — no spec-level behavior changes (see design.md for rationale).

## Impact

- **Added**: `prompts/absolute_mode.json` (new prompt definition; `prompts/` is gitignored and user-local, consistent with all other prompts).
- **Untouched**: `App.ahk`, `SystemPrompts.ahk`, `ConfigurationService.ahk`, UI, commands, controllers.
- **No dependencies** added; no build or release impact (prompts are not part of the release zip).
