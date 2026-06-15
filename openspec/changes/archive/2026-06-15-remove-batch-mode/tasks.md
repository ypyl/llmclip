## 1. Services — Remove batch state and filter methods

- [x] 1.1 Remove `batchModeEnabled` field and `SetBatchMode()` method from `Services/SessionManager.ahk`
- [x] 1.2 Remove `GetMessagesExcludingBatchForSession()` and `GetMessagesExcludingBatch()` from `Services/SessionManager.ahk`
- [x] 1.3 Remove `GetCheckedContextItems()` from `Services/SessionManager.ahk`
- [x] 1.4 Remove `isBatchMode`, `isBatchResponse`, `batchContextItem` from `internalProps` array in `Services/LLM/Types.ahk`

## 2. Commands — Delete batch commands and simplify normal send

- [x] 2.1 Delete `Commands/SendBatchToLLMCommand.ahk`
- [x] 2.2 Delete `Commands/ToggleBatchModeCommand.ahk`
- [x] 2.3 In `Commands/SendToLLMCommand.ahk`: replace `GetMessagesExcludingBatchForSession(targetSessionIndex)` with `GetSessionMessages(targetSessionIndex)`

## 3. State Persistence — Remove batch mode from save/load

- [x] 3.1 In `Commands/SaveStateOnExitCommand.ahk`: remove `batchMode` key from state object
- [x] 3.2 In `Commands/LoadStateOnStartCommand.ahk`: remove batch mode restoration block (check + restore)

## 4. Controller — Remove batch routing and toggle handler

- [x] 4.1 In `Controllers/MainController.ahk`: remove `sendBatchToLLMCommand` and `toggleBatchModeCommand` fields
- [x] 4.2 In `Controllers/MainController.ahk`: remove batch parameters from `SetCommands()` method signature and body
- [x] 4.3 In `Controllers/MainController.ahk`: remove batch items gathering and validation from `AskToLLM()` (lines ~176-179)
- [x] 4.4 In `Controllers/MainController.ahk`: remove batch mode routing branch from `AskToLLM()` (lines ~207-215)
- [x] 4.5 In `Controllers/MainController.ahk`: remove `ToggleBatchMode()` method
- [x] 4.6 In `Controllers/MainController.ahk`: remove batch mode checkbox sync from `UpdateSessionUI()` (lines ~433-434)

## 5. View — Remove Mode menu and batch UI

- [x] 5.1 In `ui/MenuView.ahk`: remove `modeMenu` field declaration
- [x] 5.2 In `ui/MenuView.ahk`: remove `modeMenu` creation and "Batch Mode" item from `Create()` method
- [x] 5.3 In `ui/MenuView.ahk`: remove `this.menuBar.Add("Mode", this.modeMenu)` from `Create()` method
- [x] 5.4 In `ui/MenuView.ahk`: remove `UpdateBatchMode()` method

## 6. Composition Root — Unwire batch commands

- [x] 6.1 In `App.ahk`: remove `#Include Commands\SendBatchToLLMCommand.ahk`
- [x] 6.2 In `App.ahk`: remove `#Include Commands\ToggleBatchModeCommand.ahk`
- [x] 6.3 In `App.ahk`: remove `sendBatchToLLM` and `toggleBatchMode` variable declarations and instantiations
- [x] 6.4 In `App.ahk`: remove batch command parameters from `SetCommands()` call

## 7. Presentation & Documentation

- [x] 7.1 In `Utils/MessagePresentationService.ahk`: remove batch indicator decoration from `GetListViewItem()` (lines checking `isBatchMode` and `isBatchResponse`)
- [x] 7.2 In `README.md`: remove two mentions of "Batch Mode"

## 8. Specs Cleanup

- [x] 8.1 Delete `openspec/specs/batch-mode/spec.md`

## 9. Integration Verification

- [x] 9.1 Run `main.ahk` — confirm menu bar has no "Mode" menu entry
- [x] 9.2 Send a normal prompt — confirm response renders correctly
- [x] 9.3 Check context items — confirm checkboxes still work and are displayed normally
- [x] 9.4 Send with context — confirm context is attached to prompt and LLM responds
- [x] 9.5 Exit and reopen — confirm state loads without errors (no stale `batchMode` key issues)
