## REMOVED Requirements

### Requirement: TempFileManager utility class
**Reason**: 30-line class providing a temp dir constant, cleanup, and path joining — all trivially inlinable. No abstraction value at 4 call sites.
**Migration**: Replace `TempFileManager.TempDir` with `A_ScriptDir "\temp"` at call sites; inline `CleanUp()` into `MainController.Start()`; inline `GetPath()` in `WebContentFetcher`.
