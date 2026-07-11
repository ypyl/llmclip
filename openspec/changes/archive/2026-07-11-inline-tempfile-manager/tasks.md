## 1. Inline TempFileManager usage

- [x] 1.1 Replace `TempFileManager.TempDir` with `A_ScriptDir "\temp"` in `LLMClient.ahk` and `PowerShellTool.ahk`
- [x] 1.2 Inline `CleanUp()` body into `MainController.ahk`, replace `GetPath()` in `WebContentFetcher.ahk`
- [x] 1.3 Remove `#Include TempFileManager.ahk` from all 4 callers
- [x] 1.4 Delete `utils/TempFileManager.ahk`
- [x] 1.5 Run `main.ahk` — verify temp dir works, no errors
