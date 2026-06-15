## Context

The "Extract Notes" feature allows users to invoke an LLM call that summarizes key learnings from the current conversation and displays them in a standalone native AHK Gui window. It was built as a one-off utility (uses a different UI paradigm than the rest of the app — native Gui vs. WebView2) and has never been used.

The feature forms a clean leaf in the architecture:
- Single command: `ExtractLearningsCommand`
- Single controller: `NotesController`
- Single view: `NotesView`
- Two service methods: `LLMService.ExtractLearnings()` and `ConfigurationService.GetLearningsPrompt()`
- One processing state constant: `ProcessingState.EXTRACTING`
- One menu entry: "Extract Notes" in the History submenu

Nothing depends on any of these components — no inbound edges in the dependency graph.

## Goals / Non-Goals

**Goals:**
- Completely remove the "Extract Notes" feature from the codebase
- Clean up all wiring, includes, and dead references
- Leave no orphaned methods, constants, or variables

**Non-Goals:**
- No refactoring of adjacent code beyond what's necessary for clean removal
- No change to the `learnings_prompt` setting in user configuration files (dead config is out of scope)
- No changes to the CI/build pipeline (no AHK files being removed affect compilation)

## Decisions

| Decision | Rationale |
|---|---|
| Delete files entirely rather than commenting out | Dead code accumulates. Files are small (22+20+32 lines), no value in preserving. Git history retains them if needed. |
| Remove `ExtractLearnings()` from `LLMService` | Called only by `ExtractLearningsCommand`. No other consumers. |
| Remove `GetLearningsPrompt()` from `ConfigurationService` | Called only by `LLMService.ExtractLearnings()`. The default "Extract valuable learnings..." prompt goes with it. |
| Remove `EXTRACTING` from `ProcessingState` | Referenced only by the extract flow. Verified zero other consumers. |
| Remove the "Extract Notes" menu item entirely | Single entry point; no other UI surface touches the feature. |
| `notesController` field and wiring removed from `MainController` | Used only for `ShowNotes()` call in `ExtractLearnings()` method. Removing the method eliminates all usage. |

## Risks / Trade-offs

No significant risks — this is a leaf removal with no dependents.

- **[Risk] Missed a reference during cleanup** → Mitigation: Search the entire codebase for every symbol being removed (`ExtractLearnings`, `EXTRACTING`, `GetLearningsPrompt`, `NotesController`, etc.) before final commit. The AGENTS.md include rules ensure `App.ahk` is the canonical reference — remove the `#Include` and AHK will fail fast on any missed reference.

- **[Risk] `CopyToClipboardCommand` is shared between `NotesController` and `HistoryViewController`** → Mitigation: `CopyToClipboardCommand` is NOT removed. Only the `NotesController` that consumes it is removed. `HistoryViewController` continues using the same instance.

- **[Trade-off] `learnings_prompt` becomes dead config** → User configuration may still contain a `learnings_prompt` key that is no longer read. Acceptable — the `ConfigurationService` stores settings generically; an unused key has zero side effects.
