## 1. Service Layer

- [x] 1.1 Simplify `RecordingService.StopRecording()` — remove `sessionManager` and `contextManager` optional params; method becomes pure `this.isRecording := false`
- [x] 1.2 Simplify `RecordingService.ToggleRecording()` — remove `sessionManager` and `contextManager` params; delegate to simplified `StartRecording()`/`StopRecording()`

## 2. Command Layer

- [x] 2.1 Update `StopRecordingCommand.__New()` — remove `sessionManager` and `contextManager` constructor params; keep only `recordingService`
- [x] 2.2 Update `StopRecordingCommand.Execute()` — call `this.recordingService.StopRecording()` with no arguments
- [x] 2.3 Update `ToggleRecordingCommand.__New()` and `Execute()` — remove `sessionManager`/`contextManager` params

## 3. Controller Layer — Merge RecordingController into MainController

- [x] 3.1 Add `OnStartRecording()` method to MainController — call `startRecordingCommand.Execute()`, then call `UpdateRecordingUI()`
- [x] 3.2 Add `OnStopRecording()` method to MainController — call `stopRecordingCommand.Execute()`, then dump recorded context to clipboard (see 3.4), then call `UpdateRecordingUI()`
- [x] 3.3 Add `OnToggleRecording()` method to MainController — replicate the show-window-if-hidden branching logic from old `RecordingController.ToggleRecording()`, then call appropriate command and `UpdateRecordingUI()`
- [x] 3.4 Add `CopyRecordedContextToClipboard()` private method to MainController — read `sessionManager.GetCurrentSessionContext()` and `contextManager.GetTextFromContextItem()`, join text, set `A_Clipboard`
- [x] 3.5 Add `UpdateRecordingUI()` method to MainController — update `topControlsView.UpdateRecordButton()` and `trayView.UpdateStatus()` based on `recordingService.isRecording`
- [x] 3.6 Add `trayView` property to MainController (backing field + `SetTrayView()` method)
- [x] 3.7 Update `MainController.ToggleDisplay()` — replace `recordingController.OnStartRecording()`/`OnStopRecording()` calls with `this.OnStartRecording()`/`this.OnStopRecording()`
- [x] 3.8 Update `MainController.AskToLLM()` — replace `this.recordingController.OnStopRecording()` call with `this.OnStopRecording()`
- [x] 3.9 Update `MainController.Start()` — replace `this.recordingController.UpdateUiBasesOnRecordingStatus()` with `this.UpdateRecordingUI()`
- [x] 3.10 Remove `recordingController` field and `recordingController` parameter from `SetSubControllers()`

## 4. Composition Root — App.ahk

- [x] 4.1 Remove `#Include Controllers\RecordingController.ahk` from App.ahk
- [x] 4.2 Remove `RecordingController` instantiation (`recordingContr := RecordingController(...)`)
- [x] 4.3 Remove `this.controller.SetSubControllers(... recordingContr)` — update call to exclude recording sub-controller
- [x] 4.4 Remove `this.view.SetSubControllers(... recordingContr)` — update call to exclude recording sub-controller
- [x] 4.5 Move `trayView := TrayView(this.controller)` BEFORE `recordingContr.SetViews(...)` / replace with direct wiring: ensure `mainController.SetTrayView(trayView)` is called directly (not via old `controller.SetTrayView` → `recordingController.SetTrayView` chain)
- [x] 4.6 Update `TopControlsView.Create()` call — change the record button callback from `recordingController.ToggleRecording` to `mainController.OnToggleRecording`
- [x] 4.7 Update `StopRecordingCommand` instantiation — remove `sess` and `ctx` constructor args
- [x] 4.8 Update `ToggleRecordingCommand` instantiation — remove `sess` and `ctx` constructor args

## 5. View Layer

- [x] 5.1 Update `TopControlsView.Create()` — accept `MainController` instead of `RecordingController` for the record button callback; update the `recordButton.OnEvent("Click", ...)` binding
- [x] 5.2 Update `MainView.BuildUI()` — pass `this.controller` (MainController) to `TopControlsView.Create()` instead of `this.recordingController`; remove `recordingController` references from MainView

## 6. Cleanup

- [x] 6.1 Delete `controllers/RecordingController.ahk`
- [x] 6.2 Verify no remaining references to `RecordingController` or `recordingController` anywhere in the codebase (`grep -r "RecordingController"`)

## 7. Integration Verification

- [x] 7.1 Run `main.ahk` and verify: tray left-click toggles recording (start/stop)
- [x] 7.2 Verify: "Start Recording" tray menu item works (no crash, recording starts)
- [x] 7.3 Verify: "Stop Recording" tray menu item works (no crash, recording stops, clipboard populated)
- [x] 7.4 Verify: F6 hotkey toggles recording
- [x] 7.5 Verify: Record/Stop button in GUI toggles recording
- [x] 7.6 Verify: Ask LLM (F7) stops recording and sends prompt
- [x] 7.7 Verify: tray icon and tooltip reflect recording state correctly
- [x] 7.8 Verify: Reset All (F5) works correctly alongside recording state
