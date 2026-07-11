## Context

`TempFileManager` is a static utility class with three members used by 4 callers:

| Member | Callers |
|--------|---------|
| `TempDir` (constant) | `LLMClient.ahk`, `PowerShellTool.ahk` |
| `CleanUp()` | `MainController.ahk` |
| `GetPath(filename)` | `WebContentFetcher.ahk` |

None of the members are complex enough to justify a separate file.

## Goals / Non-Goals

**Goals:**
- Delete `TempFileManager.ahk`
- Inline its 3 members at each call site
- Remove `#Include TempFileManager.ahk` from all callers and `App.ahk`

**Non-Goals:**
- No change to temp directory location or cleanup behavior
- No change to `WebContentFetcher.FetchMarkdown` temp file logic

## Decisions

**Decision: Replace with file-local constants.**

- `TempFileManager.TempDir` → `A_ScriptDir "\temp"` at each call site (2 sites). A local `tempDir` variable already exists in both callers — just change the assignment.
- `TempFileManager.CleanUp()` → inline the 6-line body directly in `MainController.Start()`. It's called once at startup.
- `TempFileManager.GetPath(name)` → inline `tempDir "\" name` in `WebContentFetcher`.

## Risks / Trade-offs

- **Dir path duplication**: `A_ScriptDir "\temp"` appears in 3 files (was 1). Acceptable — it's a single string, and these files are already coupled via the temp dir concept.
