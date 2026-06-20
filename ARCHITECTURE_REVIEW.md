# Architecture Review — Issues & Findings

Generated: 2026-06-18 | Reviewer: automated analysis against `ARCHITECTURE.md`

---

## Severity Levels

| Tag | Meaning |
|-----|---------|
| 🔴 **BUG** | Runtime error, crash, or data loss |
| 🟠 **VIOLATION** | Clear architecture rule break |
| 🟡 **SMELL** | Design concern, likely to cause issues |
| 🔵 **STYLE** | Naming, duplication, or doc inconsistency |

---

## 1. ~~🔴 BUG — TrayView calls non-existent methods on MainController~~ ✅ DONE (2026-06-20)

**File**: `ui/TrayView.ahk:12-13`

```ahk
A_TrayMenu.Add("Start Recording", (*) => this.controller.OnStartRecording())
A_TrayMenu.Add("Stop Recording", (*) => this.controller.OnStopRecording())
```

**Problem**: `TrayView` receives `MainController` as `controller`, but `MainController` does **not** define `OnStartRecording()` or `OnStopRecording()`. These methods exist only on `RecordingController`. Clicking either tray menu item will throw a runtime `Property not found` error.

**Fix**: Route through `ToggleDisplay()` (which exists on `MainController` and delegates correctly), or wire the tray directly to `RecordingController`.

---

## 2. ~~🔴 VIOLATION — Controller → Controller direct calls~~ ✅ DONE (2026-06-20)

**File**: `controllers/MainController.ahk`

Multiple locations call sub-controller methods directly instead of going through commands or callbacks:

```ahk
; MainController.ToggleDisplay() — line ~91
this.recordingController.OnStartRecording()
...
this.recordingController.OnStopRecording()

; MainController.AskToLLM() — line ~128
this.recordingController.OnStopRecording()
```

**Rule**: ARCHITECTURE.md §2 — "⛔ Forbidden: … Controller → Controller calls."

**Why it matters**: Breaks separation of concerns. RecordingController's internal state may not be in sync. The MainController should invoke commands or use callbacks (like the `onSessionChanged`/`onSystemPromptChanged` pattern used for `SettingsController`), not reach into sub-controller methods.

**Fix**: Route through a dedicated command (e.g., `StopRecordingCommand` already exists and is wired in `App.ahk`) or set up a callback on `MainController` that `RecordingController` calls.

---

## 3. ~~🟠 VIOLATION — Controller mutates service during construction~~ ✅ DONE (2026-06-20)

**File**: `controllers/HistoryViewController.ahk:45-47`

```ahk
if (this.webViewManager) {
    this.webViewManager.SetSaveEditCallback(ObjBindMethod(this, "OnMessageEdited"))
}
```

**Rule**: ARCHITECTURE.md §3 — "Controller → Service: **Read-only** access."

`SetSaveEditCallback()` mutates `WebViewManager` state. This wiring should happen in `App.ahk` after construction, following the same property-assignment-after-construction pattern used for Views and Controllers.

**Fix**: Move the `SetSaveEditCallback` call to `App.ahk`:

```ahk
histView := HistoryViewController(...)
wv.SetSaveEditCallback(ObjBindMethod(histView, "OnMessageEdited"))
```

---

## 4. ~~🟡 SMELL — RecordingService is tightly coupled to SessionManager/ContextManager~~ ✅ DONE (2026-06-20)

**File**: `services/RecordingService.ahk`

```ahk
StopRecording(sessionManager := "", contextManager := "") {
    if (this.isRecording) {
        this.isRecording := false
        if (sessionManager && contextManager) {
            recordedText := ""
            context := sessionManager.GetCurrentSessionContext()
            for item in context {
                recordedText .= contextManager.GetTextFromContextItem(item.Value)
            }
            A_Clipboard := recordedText   ; <-- side effect
        }
        return true
    }
    return false
}
```

Three concerns:
1. **Service-to-service coupling**: `RecordingService` receives `SessionManager` and `ContextManager` as method parameters and calls their methods. This creates hidden temporal coupling.
2. **Side effect**: Sets `A_Clipboard` directly as a side-effect of stopping recording. The caller has no indication this will happen.
3. **Optional dependencies**: The `:= ""` defaults allow the method to be called without context dumping, creating two distinct code paths.

**Fix**: Move the "dump context to clipboard on stop" logic into the `StopRecordingCommand` or a dedicated command. `RecordingService.StopRecording()` should only toggle `isRecording := false`.

---

## 5. 🟡 SMELL — MarkdownNewTool used outside LLM tool-call context

**File**: `commands/ReplaceLinkWithContentCommand.ahk:22`

```ahk
markdownContent := this.markdownNewTool.Execute(contextItem)
```

**Problem**: `ReplaceLinkWithContentCommand` calls `MarkdownNewTool.Execute()` directly (not through `ExecuteToolCall()`). The tool is instantiated in `App.ahk` as an LLM tool (`mnt`) then aliased and passed to the command as a dependency. This:
- Bypasses the LLM's tool-call mechanism
- Uses the tool for direct HTTP requests from a user-facing command
- Couples the command to a specific tool implementation

**Fix**: Extract the HTTP fetch logic into a separate utility or service (e.g., `WebContentFetcher`), keeping `MarkdownNewTool` only for the LLM tool-call path.

---

## 6. 🟡 SMELL — MenuView has domain knowledge of tool names

**File**: `ui/MenuView.ahk:13-19`

```ahk
static ToolMapping := [
    { id: PowerShellTool.TOOL_NAME, label: "PowerShell", stateKey: PowerShellTool.TOOL_NAME },
    { id: FileSystemTool.TOOL_NAME, label: "File System", stateKey: FileSystemTool.TOOL_NAME },
    ...
]
```

**Problem**: `MenuView` (a View — structure only) references constants from `PowerShellTool`, `FileSystemTool`, etc. — classes in the service layer. This creates an indirect dependency from UI to service internals and means the View must `#Include` all tool files (done transitively via `MainView.ahk`).

**Fix**: Have the controller (or a command) provide the tool list as data. The View should receive `[{id, label}]` from outside, not define it.

---

## 7. 🔵 STYLE — Duplicate `_SortDescending` method

**Files**:
- `commands/DeleteMessageCommand.ahk:20-33`
- `controllers/HistoryViewController.ahk:120-133`

Both have an identical `_SortDescending` helper. Should be extracted to `Utils/` as a static helper.

---

## 8. 🔵 STYLE — "Service" naming in `Utils/` directory

**Files**: `Base64Service.ahk`, `ClipboardParserService.ahk`, `ClipboardImageService.ahk`, `ClipboardService.ahk`, `FileService.ahk`, `MessagePresentationService.ahk`, `PdfService.ahk`, `StateService.ahk`

All reside in `Utils/` and have only static methods, but are named `*Service`. In the architecture, "Service" means a state-owning class instantiated in `App.ahk`. This naming blurs the distinction.

**Fix**: Rename to `*Helper` or `*Utils` (e.g., `Base64Helper`, `ClipboardParser`).

---

## 9. 🔵 STYLE — Doc references non-existent file

**File**: `AGENTS.md:11`

References `services/Configuration/Roles.ahk` in the key files table. This file does not exist. `SystemPrompts.ahk` handles all prompt-related configuration.

**Fix**: Update AGENTS.md to remove the `Roles.ahk` reference or replace with `SystemPrompts.ahk`.

---

## 10. 🔵 STYLE — `check.ahk` is development-only tooling in project root

**File**: `check.ahk`

A standalone GUI script for browsing `shell32.dll` icons — unrelated to the LLMClip application. Should be in a `tools/` or `dev/` directory, or removed.

---

## 11. ~~🟡 SMELL — Direct service reads with control flow in MainController.ToggleDisplay~~ ✅ DONE (2026-06-20)

**File**: `controllers/MainController.ahk:91`

```ahk
ToggleDisplay() {
    if (!this.recordingService.isRecording) {
        this.recordingController.OnStartRecording()
    } else if (!this.mainView.guiShown) {
        this.mainView.Show()
    } else {
        this.recordingController.OnStopRecording()
    }
}
```

Combines a direct service read (`recordingService.isRecording`), controller-to-controller calls, and View manipulation in a single method. This logic should be in `RecordingController` or a dedicated command.

---

## Summary

| # | Severity | Area | Issue |
|---|----------|------|-------|
| 1 | ~~🔴 BUG~~ ✅ | TrayView→MainController | Methods `OnStartRecording`/`OnStopRecording` don't exist on MainController — runtime crash |
| 2 | ~~🔴 VIOLATION~~ ✅ | MainController | Controller→Controller calls to RecordingController |
| 3 | ~~🟠 VIOLATION~~ ✅ | HistoryViewController | Mutates service (`SetSaveEditCallback`) during construction |
| 4 | ~~🟡 SMELL~~ ✅ | RecordingService | Tightly coupled to SessionManager/ContextManager; clipboard side-effect |
| 5 | 🟡 SMELL | ReplaceLinkWithContent | Uses LLM tool outside tool-call path |
| 6 | 🟡 SMELL | MenuView | Has domain knowledge of tool names from service layer |
| 7 | 🔵 STYLE | DeleteMessageCommand, HistoryViewController | Duplicate `_SortDescending` method |
| 8 | 🔵 STYLE | Utils/ | "Service" suffix on static-only utility classes |
| 9 | 🔵 STYLE | AGENTS.md | References non-existent `Roles.ahk` |
| 10 | 🔵 STYLE | Root | Dev-only `check.ahk` in project root |
| 11 | ~~🟡 SMELL~~ ✅ | MainController | ToggleDisplay mixes concerns (service read + controller call + view manipulation) |

### Recommended Fix Order (updated 2026-06-20)

1. **#5** — Extract web content fetching from MarkdownNewTool
2. **#6** — Decouple MenuView from tool constants
3. **#7**, **#8**, **#9**, **#10** — Style cleanup (low priority)
