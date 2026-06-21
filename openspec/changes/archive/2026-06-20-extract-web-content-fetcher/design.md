## Context

Currently, two consumers need to fetch web content via `https://markdown.new/`:

1. **`MarkdownNewTool`** (LLM tool path) — invoked by the LLM via `ExecuteToolCallsCommand` → `LLMService` → `toolsMap`
2. **`ReplaceLinkWithContentCommand`** (user command path) — invoked when the user clicks "Replace Link with Content" in the context view

Both point at the same `MarkdownNewTool` instance. The command receives `mdn := mnt` (an alias) from `App.ahk` and calls `Execute()` directly, bypassing the tool-call mechanism. This couples the commands layer to a class in `services/LLM/`.

Additionally, `MarkdownNewTool.Execute()` and `ReplaceLinkWithContentCommand.Execute()` both parse the JSON response from markdown.new — `MarkdownNewTool` for error detection, the command for content/title extraction. This is brittle duplication.

`ReplaceLinkWithContentCommand` already includes `#Include ..\Lib\Json.ahk` and `MarkdownNewTool` includes `#Include ..\..\Lib\Json.ahk` and `#Include ..\..\Utils\TempFileManager.ahk`.

## Goals / Non-Goals

**Goals:**
- Break the dependency from `ReplaceLinkWithContentCommand` → `MarkdownNewTool`
- Extract the HTTP fetch logic into a reusable static utility
- Eliminate the `mdn := mnt` alias in `App.ahk`

**Non-Goals:**
- Changing the JSON parsing logic or response format in either consumer
- Adding mid-flight cancellation to the utility (not needed by the command, and the tool's upfront cancellation check is sufficient)
- Refactoring any other tool or command

## Decisions

### Decision 1: Static utility vs. stateful service

**Chosen**: Static utility (`Utils/WebContentFetcher.ahk`) with a single `FetchMarkdown(url)` static method.

**Rationale**: The HTTP logic is purely functional (input URL → output string) and has no persistent state of its own. Static methods are the pattern for `Utils/` in this project (see `Base64Service`, `ClipboardParserService`, `FileService`, etc.). A stateful service would add unnecessary complexity.

**Alternative considered**: Stateful service with cancellation. Rejected — `ReplaceLinkWithContentCommand` doesn't need cancellation, and the tool's upfront `isCancelled` check handles the common case. Mid-flight cancellation during curl execution is a minor UX edge case.

### Decision 2: What the utility returns

**Chosen**: Raw string response from markdown.new (may be JSON or markdown).

**Rationale**: Each consumer has different JSON parsing needs:
- `MarkdownNewTool` — detects error JSON (`success: 0`) and returns error string; passes through everything else raw for the LLM
- `ReplaceLinkWithContentCommand` — extracts `content` and `title` from success JSON, formats for context

Returning raw content keeps the utility simple and lets each consumer parse appropriately.

**Alternative considered**: Parsed structured result `{success, content, title}`. Rejected — would require `MarkdownNewTool` to re-stringify for the LLM, adding complexity for no benefit.

### Decision 3: Mid-flight cancellation

**Chosen**: Remove the in-loop cancellation check from the curl wait. Keep only the upfront `isCancelled` check before launching curl.

**Rationale**: The while loop polling `ProcessExist` with `this.isCancelled` checks is the only stateful part of `Execute()`. Moving it to the static utility would require a cancellation callback — complex and unnecessary for a <5 second fetch. If the user cancels before curl starts, it's caught. If during, they wait a few seconds. This is consistent with the command path (which never had cancellation).

### Decision 4: TempFileManager and JSON dependencies

**Chosen**: `WebContentFetcher` includes its own `#Include` for `Lib\Json.ahk` and `Utils\TempFileManager.ahk` (relative from `Utils/`).

**Rationale**: These are already vendored/utility files, not services. The static utility approach is consistent with other `Utils/` files that include `Lib\` dependencies.

## Risks / Trade-offs

- **[Risk] `ReplaceLinkWithContentCommand` breaks if `WebContentFetcher.FetchMarkdown()` has different error handling than `MarkdownNewTool.Execute()`** → **Mitigation**: Copy the curl logic exactly from `MarkdownNewTool.Execute()`. The JSON parsing in the command is unchanged and independent.
- **[Risk] Mid-flight cancellation removed for tool path** → **Mitigation**: Only applies to the brief curl execution window (typically <5s). The upfront cancellation check remains. If this becomes an issue, revisit with a stateful service approach.
- **[Risk] Duplicate TempFileManager/JSON includes** → **Mitigation**: Both files already include these in the current code; no new duplication introduced. `WebContentFetcher` includes them once from `Utils/` perspective.
