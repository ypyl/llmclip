## Why

`TempFileManager` is a 30-line class providing three things used by 4 files: a temp directory constant, a `CleanUp()` method, and a `GetPath()` path-joiner. All three are trivially inlined — the constant is `A_ScriptDir "\temp"`, CleanUp is delete+recreate, and GetPath is string concatenation. The class adds an indirection layer and an extra file for no real abstraction gain.

## What Changes

- Replace `TempFileManager.TempDir` with a direct `A_ScriptDir "\temp"` string at the 2 call sites
- Inline `TempFileManager.CleanUp()` into `MainController.Start()` as a local one-liner
- Replace `TempFileManager.GetPath(name)` with inline path concatenation in `WebContentFetcher`
- Delete `TempFileManager.ahk`
- Remove `#Include` lines from callers and `App.ahk`

## Capabilities

### New Capabilities
<!-- None — inline refactor, no behavior change -->

### Modified Capabilities
<!-- None -->

## Impact

- **Affected code**: `TempFileManager.ahk` (deleted), `MainController.ahk`, `LLMClient.ahk`, `PowerShellTool.ahk`, `WebContentFetcher.ahk`, `App.ahk` (#Include removal)
- **No behavior change**
