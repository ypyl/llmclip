## 1. Create the prompt file

- [x] 1.1 Create `prompts/absolute_mode.json` with a single top-level key `absolute_mode` whose `value` contains the Absolute Mode system prompt (see design.md D3 for content direction)
- [x] 1.2 Validate the file parses as JSON (e.g. `python -m json.tool prompts/absolute_mode.json`)

## 2. Verify

- [x] 2.1 Start the app (`main.ahk`) and confirm `absolute_mode` appears in the system prompt selector alongside the existing prompts
- [x] 2.2 Select `absolute_mode`, send a test prompt, and confirm the response contains the requested material only — no filler, emojis, soft closures, or follow-up questions
- [x] 2.3 Confirm the default `_` prompt and all existing prompts still behave unchanged
