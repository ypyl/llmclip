## Why

The ponytail audit identified ~365 lines of dead code and config across the codebase: un-included utility files, unreferenced type classes, an abandoned config file, and trivial delegation that adds no value. This is dead weight — it increases scan time, confuses navigation, and misleads maintenance. Clean it up now while it's catalogued.

## What Changes

- Delete `tools/check.ahk` — unrelated debug tool (shell32 icon viewer), never included
- Delete `Utils/PdfHelper.ahk` — planned but never wired in, never included
- Delete `Utils/ClipboardHelper.ahk` — trivial one-liner wrappers around `A_Clipboard`; inline the single call site
- Remove dead type classes from `Services/LLM/Types.ahk` — `ChatRole`, `ChatOptions`, `UsageDetails`, `ChatChoice`, `ChatResponse` — defined but never instantiated
- Remove dead method `AddTokensToResult()` from `Services/LLM/Providers/BaseProvider.ahk` — never called by any subclass
- Remove abandoned `roles.json` config — role-based filtering disabled, never loaded at runtime
- Remove `#Include` entries in `App.ahk` for deleted files
- Delete `TODO.md` after all items are implemented (the tracking file for this work)

## Capabilities

### New Capabilities

None — this is a maintenance-only cleanup. No behavioral changes, no new features.

### Modified Capabilities

None — no requirement-level changes. Only dead code removal.

## Impact

- Affected files: `tools/check.ahk`, `Utils/PdfHelper.ahk`, `Utils/ClipboardHelper.ahk`, `Commands/CopyToClipboardCommand.ahk`, `Services/LLM/Types.ahk`, `Services/LLM/Providers/BaseProvider.ahk`, `App.ahk`, `roles.json`, `TODO.md`
- No API changes, no dependency changes, no breaking changes
- Verification: run `main.ahk`, verify LLM calls work, verify clipboard copy works, verify no include errors
