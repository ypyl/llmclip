## Context

`RecordingController` was extracted from `MainController` as a sub-controller to encapsulate recording-specific UI coordination. In practice, the extraction failed: `MainController` still reaches directly into `RecordingController` for every recording action (`ToggleDisplay`, `AskToLLM`, `Start`). `RecordingController`'s 4 methods are thin proxies (command → update UI) with no unique logic. The only "smart" behavior — the show-window-if-hidden branch in `ToggleRecording` — is a UI-coordination decision that belongs in `MainController`.

Additionally, `TrayView` was constructed with `MainController` as its `controller` parameter, but its menu callbacks reference `OnStartRecording()`/`OnStopRecording()` — methods that only exist on `RecordingController`. This is a runtime crash path.

### Current wiring (simplified)

```
App.ahk:
  rec := RecordingService()
  startRec := StartRecordingCommand(rec)
  stopRec := StopRecordingCommand(rec, sess, ctx)
  toggleRec := ToggleRecordingCommand(rec, sess, ctx)
  recordingContr := RecordingController(rec, startRec, stopRec, toggleRec)

  MainController(..., rec)
    .SetSubControllers(..., recordingContr)

  recordingContr.SetViews(topControlsView, mainView)
  trayView := TrayView(mainController)         ← passes MainController
  mainController.SetTrayView(trayView)          ← forwards to RC.SetTrayView

Call paths:
  trayView → mainController.OnStartRecording()   ← 💥 doesn't exist
  trayView → mainController.OnStopRecording()    ← 💥 doesn't exist
  F6 hotkey → mainController.ToggleDisplay() → RC.OnStartRecording/OnStopRecording()
  AskToLLM() → RC.OnStopRecording()
  record btn → RC.ToggleRecording()
```

## Goals / Non-Goals

**Goals:**
- Eliminate controller-to-controller calls in the recording flow
- Fix the runtime crash in TrayView menu handlers
- Remove the hollow `RecordingController` layer
- Simplify `RecordingService.StopRecording()` to be pure (no clipboard side-effect, no optional cross-service params)
- Keep all user-facing recording behavior identical

**Non-Goals:**
- Changing how clipboard capture works during recording
- Changing tray icon behavior
- Modifying the `ProcessClipboardCommand` recording check
- Touching hotkey bindings (F5/F6/F7)
- Renaming or restructuring any command other than `StopRecordingCommand`

## Decisions

### D1: Merge RecordingController into MainController (not fix in-place with callbacks)

**Alternatives considered:**

| Approach | Pros | Cons |
|----------|------|------|
| **A: Merge into MainController** ✅ | Eliminates the hollow layer; fixes bug + violation in one step; reduces total code | MainController gains ~25 lines |
| B: Keep RC, add callbacks (like SettingsController pattern) | Consistent with SettingsController pattern | Preserves hollow abstraction; more indirection for 3-line methods; doesn't simplify StopRecordingCommand |
| C: Keep RC, just add missing methods to MainController | Minimal change | Leaves controller-to-controller violations in place; kicks the can |

**Decision: Approach A.** RecordingController's methods are too thin to justify the indirection. MainController already holds all recording dependencies (the 3 commands, `RecordingService`, `TrayView`, `TopControlsView`). The merge eliminates 2 architectural violations and 1 runtime bug in one change.

### D2: Where to handle the clipboard-dump-on-stop

Currently `RecordingService.StopRecording(sessionManager, contextManager)` iterates over context and sets `A_Clipboard`. This is a UI/OS side-effect in a Service.

**Alternatives considered:**

| Approach | Pros | Cons |
|----------|------|------|
| **A: Move to MainController** | Controller reads session context (allowed, read-only), sets clipboard via View or Utils | Controller gains OS-side-effect logic |
| **B: Extract to a Command** | Follows "Commands mutate" rule | The clipboard dump isn't a use-case on its own; adds another Command file |
| C: Leave in StopRecordingCommand | Command already has sessionManager/contextManager | Command should delegate to service, not do the work itself |

**Decision: Approach A.** The clipboard dump on stop is a UI-coordination concern — it reads the session's recorded context and puts it where the user expects. MainController already coordinates UI concerns post-recording. The logic moves into `MainController.OnStopRecording()`:

```ahk
OnStopRecording() {
    this.stopRecordingCommand.Execute()
    this.CopyRecordedContextToClipboard()  ; new
    this.UpdateRecordingUI()
}
```

### D3: RecordingService API simplification

`RecordingService.StopRecording()` and `ToggleRecording()` currently accept optional `sessionManager`/`contextManager` params solely for the clipboard dump. After removing the side-effect:

- `StopRecording()` → `this.isRecording := false` (pure flag toggle)
- `ToggleRecording()` → delegates to `StartRecording()`/`StopRecording()` (also pure)
- `StopRecordingCommand` no longer needs `SessionManager`/`ContextManager` dependencies

### D4: View wiring

After the merge, `TrayView` and `TopControlsView` both reference `MainController` directly:

| Before | After |
|--------|-------|
| `TopControlsView.recordButton` → `RecordingController.ToggleRecording` | → `MainController.OnToggleRecording` |
| `TrayView.menu "Start Recording"` → `controller.OnStartRecording()` (broken) | → `mainController.OnStartRecording()` (fixed) |
| `TrayView.menu "Stop Recording"` → `controller.OnStopRecording()` (broken) | → `mainController.OnStopRecording()` (fixed) |
| `TrayView left-click` → `controller.ToggleDisplay()` | Unchanged (already works) |

### D5: What stays, what goes

**Moves from RecordingController → MainController:**
- `OnStartRecording()`
- `OnStopRecording()` (gains clipboard-dump logic formerly in RecordingService)
- `OnToggleRecording()` (gains the show-window-if-hidden branch)
- `UpdateRecordingUI()` (renamed from `UpdateUiBasesOnRecordingStatus`)
- `trayView` reference + `SetTrayView()`
- `topControlsView` reference (already held by MainController)

**Kept unchanged:**
- `StartRecordingCommand`, `StopRecordingCommand`, `ToggleRecordingCommand`
- `RecordingService` (except StopRecording params)
- `ProcessClipboardCommand`
- Hotkey bindings (F5/F6/F7)

**Deleted:**
- `controllers/RecordingController.ahk`
- `App.ahk` lines importing and wiring RecordingController

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| MainController grows beyond its "coordination" role | Recording methods are thin (call command → update UI). 25 extra lines on a ~370 line controller is manageable. If MainController later needs decomposition, extract recording as a Command orchestration, not a Controller. |
| Clipboard-dump-on-stop behavior changes | Behavior preserved identically — just moved. Manual test: record → copy text/files → stop → verify A_Clipboard contains expected context. |
| TrayView constructor signature | No change needed — it already receives MainController. The methods just need to exist. |
| TopControlsView record button callback change | The callback change from `recordingController.ToggleRecording` to `mainController.OnToggleRecording` is a wiring change in `App.ahk` (where MainView.BuildUI passes the controller to TopControlsView.Create). Must be updated there. |

## Open Questions

- **Should the clipboard dump on stop be configurable?** Currently it always dumps. Some users may not want this. Out of scope for this change — but extracting it into its own method makes it trivially configurable later.
