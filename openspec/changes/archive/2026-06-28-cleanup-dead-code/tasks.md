## 1. Delete standalone dead files

- [x] 1.1 Delete `tools/check.ahk` (unrelated shell32 icon viewer, never included)
- [x] 1.2 Delete `Utils/PdfHelper.ahk` (never included, no callers)
- [x] 1.3 Delete `roles.json` (abandoned config, never loaded)

## 2. Remove dead code from live files

- [x] 2.1 Remove `ChatRole` class from `Services/LLM/Types.ahk` (dead, static constants never referenced)
- [x] 2.2 Remove `ChatOptions` class from `Services/LLM/Types.ahk` (dead, replaced by plain Map)
- [x] 2.3 Remove `UsageDetails` class from `Services/LLM/Types.ahk` (dead, replaced by AdditionalProperties)
- [x] 2.4 Remove `ChatChoice` and `ChatResponse` classes from `Services/LLM/Types.ahk` (dead, providers return ChatMessage[] directly)
- [x] 2.5 Remove `AddTokensToResult()` method from `Services/LLM/Providers/BaseProvider.ahk` (never called)

## 3. Inline trivial delegation

- [x] 3.1 Inline `ClipboardHelper.SetText` into `Commands/CopyToClipboardCommand.ahk` (replace with `A_Clipboard := text`)
- [x] 3.2 Delete `Utils/ClipboardHelper.ahk`
- [x] 3.3 Remove `#Include Utils\ClipboardHelper.ahk` from `App.ahk`

## 4. Clean up App.ahk include registry

- [x] 4.1 Remove `#Include Utils\ClipboardHelper.ahk` from `App.ahk` (if not already done in 3.3)

## 5. Verification

- [x] 5.1 Run `main.ahk` — verify application starts without include errors (static check: all `#Include` paths resolve)
- [x] 5.2 Test clipboard copy — select a message in history, click Copy, verify text on system clipboard
- [x] 5.3 Test LLM call — send a prompt, verify response renders in WebView

## 6. Final cleanup

- [x] 6.1 Delete `TODO.md` (tracking file, work complete)
