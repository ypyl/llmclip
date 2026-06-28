## Context

The ponytail audit surfaced ~365 lines of dead code, unused type classes, and abandoned config. None of these are referenced by the runtime — deleting them is pure removal with no behavioral change.

Current state:
- `tools/check.ahk` — exists but never `#Include`d in `App.ahk`
- `Utils/PdfHelper.ahk` — exists but never `#Include`d
- `Utils/ClipboardHelper.ahk` — included and used by exactly one call site (`CopyToClipboardCommand`)
- `Services/LLM/Types.ahk` — contains 5 type classes that are defined but never instantiated by any other file
- `Services/LLM/Providers/BaseProvider.ahk` — contains `AddTokensToResult()` which is never called
- `roles.json` — exists in root but never loaded (role-based filtering is disabled in code)

## Goals / Non-Goals

**Goals:**
- Remove all files and code segments identified as unreachable dead code
- Clean up `App.ahk` include declarations for removed files
- Inline trivial delegation where it removes a whole file
- Verify the application runs and core functions work after removal

**Non-Goals:**
- No refactoring of live code
- No restructuring of the architecture (command-per-usecase stays)
- No changes to `Lib/` vendored dependencies
- No evaluation of whether architectural choices are over-engineered

## Decisions

### 1. Inline ClipboardHelper into CopyToClipboardCommand

`ClipboardHelper.SetText(text)` does `A_Clipboard := text`. `CopyToClipboardCommand.Execute(text)` calls `ClipboardHelper.SetText(text)`. Instead, make `CopyToClipboardCommand.Execute(text)` do `A_Clipboard := text` directly, then delete `ClipboardHelper.ahk` and its `#Include` from `App.ahk`.

**Alternative considered**: Keep ClipboardHelper "just in case." Rejected — YAGNI. One call site, no future callers projected.

### 2. Remove dead type classes from Types.ahk by section deletion

`ChatRole`, `ChatOptions`, `UsageDetails`, `ChatChoice`, and `ChatResponse` are defined ~104 lines in `Types.ahk` but never used. No file instantiates `new ChatRole(...)`, `new ChatOptions(...)`, `new UsageDetails(...)`, `new ChatChoice(...)`, or `new ChatResponse(...)`. Delete their class definitions. The actively-used classes (`ChatContent` hierarchy, `ChatMessage`) remain untouched.

**Alternative considered**: Leave them "for documentation." Rejected — they document a design that was never adopted and mislead future readers.

### 3. Delete entire files (no inline changes needed)

`tools/check.ahk`, `Utils/PdfHelper.ahk`, `roles.json` — these are standalone files with zero inbound references. Simple file deletion.

### 4. Remove `AddTokensToResult` from BaseProvider

This method exists only in `BaseProvider.ahk` and is never called by any subclass. All providers (OpenAI, Google, Ollama) inline token extraction in their own `ParseResponse`. Delete the method body.

## Risks / Trade-offs

- **Risk**: `ChatMessage.FromObject` or other serialization code references the deleted types internally → **Mitigation**: verified via grep — no file references `ChatRole`, `ChatOptions`, `UsageDetails`, `ChatChoice`, or `ChatResponse` outside `Types.ahk` itself.
- **Risk**: Some other `.ahk` file (outside the tracked includes) depends on deleted files → **Mitigation**: all dependencies are declared in `App.ahk`; files not listed there are unreachable by AHK's `#Include` system.
- **Risk**: `roles.json` is loaded by some indirect path (e.g., shelled out to a script) → **Mitigation**: grep confirms no AHK file references "roles.json" or "roles".
- **Trade-off**: Losing `ChatRole` static constants means no central definition of role strings — but role strings are already hardcoded as string literals everywhere (`"system"`, `"user"`, etc.).
