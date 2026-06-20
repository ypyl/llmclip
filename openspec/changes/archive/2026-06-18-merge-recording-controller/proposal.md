## Why

Three intertwined problems in the recording flow block further work and cause a runtime crash:

1. **TrayView calls non-existent methods on MainController** — clicking "Start Recording" or "Stop Recording" from the tray menu crashes with a `Property not found` error because `OnStartRecording()`/`OnStopRecording()` live on `RecordingController`, not on `MainController` (which TrayView receives).

2. **Controller-to-controller calls** — `MainController.ToggleDisplay()` and `AskToLLM()` reach directly into `recordingController.OnStartRecording()`/`OnStopRecording()`, violating the architecture's ban on cross-controller calls.

3. **RecordingController is a hollow proxy** — its 4 methods are 3-line delegates (call command → update UI). It owns no unique logic, carries no independent state, and exists only as an extra hop between MainController and the recording commands. The extraction didn't encapsulate anything.

These must be fixed before the recording feature gains any real complexity (e.g., audio recording, per-session recording state).

## What Changes

- **Merge `RecordingController` into `MainController`** — all recording-triggering methods move to MainController, which already holds the recording commands and reads `RecordingService`
- **Delete `RecordingController`** — its methods (`OnStartRecording`, `OnStopRecording`, `OnToggleRecording`, `UpdateUiBasesOnRecordingStatus`) become MainController methods
- **Wire TrayView and TopControlsView directly to MainController** — eliminate the intermediate controller references
- **Remove `#Include` for RecordingController from `App.ahk`** and remove recording controller wiring
- **Fix TrayView bug** — methods now exist where they're called, resolving the runtime crash
- **Clean `RecordingService.StopRecording()`** — remove optional `SessionManager`/`ContextManager` params and the clipboard-dump side effect (moved to a command or to MainController orchestration)
- **Clean `StopRecordingCommand`** — remove `SessionManager`/`ContextManager` dependencies once the service is pure

## Capabilities

### New Capabilities

None — this is a pure architectural refactoring. No user-facing behavior changes.

### Modified Capabilities

None — no spec-level requirements are changing. Recording semantics (start captures clipboard, stop finalizes, tray icon reflects state) remain identical.

## Impact

- **Deleted**: `controllers/RecordingController.ahk`
- **Modified**: `controllers/MainController.ahk` — gains recording methods and recording UI coordination
- **Modified**: `App.ahk` — removes `RecordingController` import and wiring; TrayView/TopControlsView wired directly to MainController
- **Modified**: `ui/TrayView.ahk` — may change constructor parameter to receive MainController directly (already does — just the method names now resolve)
- **Modified**: `ui/TopControlsView.ahk` — record button callback changes from `recordingController.ToggleRecording` to `mainController.OnToggleRecording`
- **Modified**: `Services/RecordingService.ahk` — `StopRecording()` becomes pure (no optional params, no clipboard side-effect)
- **Modified**: `Commands/StopRecordingCommand.ahk` — removes `SessionManager`/`ContextManager` deps
- **No API changes, no config changes, no build changes**
