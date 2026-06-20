## Why

`ReplaceLinkWithContentCommand` depends directly on `MarkdownNewTool` — a class in `services/LLM/` designed for the LLM tool-call path. The command calls `Execute()` directly, bypassing the tool-call mechanism and creating a coupling from the commands layer to the LLM service layer. Additionally, both `MarkdownNewTool.Execute()` and `ReplaceLinkWithContentCommand.Execute()` contain near-identical JSON parsing logic, a brittle code duplication.

This is the next open 🟡 SMELL in ARCHITECTURE_REVIEW.md (#5).

## What Changes

- Create `Utils/WebContentFetcher.ahk` — a static helper with a single `FetchMarkdown(url)` method containing the pure HTTP logic (curl → markdown.new → return raw response)
- Refactor `MarkdownNewTool.Execute()` to delegate HTTP work to `WebContentFetcher.FetchMarkdown()`, retaining only the upfront cancellation check (lose mid-flight cancellation — acceptable trade-off for typical <5s fetches)
- Refactor `ReplaceLinkWithContentCommand` to use `WebContentFetcher.FetchMarkdown()` directly instead of `MarkdownNewTool.Execute()`, and keep only its own JSON parsing and context formatting
- Remove the `mdn := mnt` alias in `App.ahk`; wire `ReplaceLinkWithContentCommand` without the tool dependency
- Add `#Include` for the new file in `App.ahk`

## Capabilities

### New Capabilities

None — structural refactor. Web content fetching and link replacement behave identically.

### Modified Capabilities

None — no spec-level requirements change.

## Impact

- **New**: `Utils/WebContentFetcher.ahk`
- **Modified**: `services/LLM/MarkdownNewTool.ahk`, `commands/ReplaceLinkWithContentCommand.ahk`, `App.ahk`
- **Trade-off**: Mid-flight cancellation for `MarkdownNewTool` fetches is lost (curl runs to completion even if user cancels LLM request). Upfront cancellation check remains. Typical fetch <5 seconds.
