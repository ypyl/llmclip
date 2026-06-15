## 1. View Layer — Remove Answer Size menu from MenuView

- [x] 1.1 Remove `answerSizeMenu` field declaration from `ui/MenuView.ahk`
- [x] 1.2 Remove `answerSizeMenu` menu creation block (3 `Add` lines + `Check("Default")` line) from `MenuView.Create()`
- [x] 1.3 Remove `menuBar.Add("Answer Size", this.answerSizeMenu)` line from `MenuView.Create()`
- [x] 1.4 Remove `UpdateAnswerSizeMenu(selectedSize)` method entirely from `MenuView`

## 2. Controller Layer — Remove answer size coordination from SettingsController

- [x] 2.1 Remove `changeAnswerSizeCommand` field from `SettingsController`
- [x] 2.2 Remove `changeAnswerSizeCommand` from `SettingsController.__New()` constructor parameters and assignment
- [x] 2.3 Remove `SelectAnswerSize(ItemName, ItemPos, MyMenu)` method entirely from `SettingsController`

## 3. Command Layer — Delete ChangeAnswerSizeCommand, clean up callers

- [x] 3.1 Delete `Commands/ChangeAnswerSizeCommand.ahk` file
- [x] 3.2 Remove `answerSize := this.sessionManager.answerSize` line and `answerSize` argument from `LLMService.SendToLLM()` call in `Commands/SendToLLMCommand.ahk`
- [x] 3.3 Remove `answerSize: this.sessionManager.answerSize` from state object in `Commands/SaveStateOnExitCommand.ahk`
- [x] 3.4 Remove answer-size restoration block (the `hasAnswerSize` guard + `SetAnswerSize()` call) from `Commands/LoadStateOnStartCommand.ahk`

## 4. Service Layer — Remove answer size from SessionManager and LLMService

- [x] 4.1 Remove `answerSize := "Default"` field and `SetAnswerSize(size)` method from `Services/SessionManager.ahk`
- [x] 4.2 Remove `answerSize` parameter from `LLMService.SendToLLM()` signature in `Services/LLM/LLMService.ahk`
- [x] 4.3 Remove the 3-branch answer-size injection block (`answerSizeMsg` variable, if/else-if, message push/pop) from `LLMService.SendToLLM()` body

## 5. Composition Root — Clean up App.ahk wiring

- [x] 5.1 Remove `#Include Commands\ChangeAnswerSizeCommand.ahk` from `App.ahk`
- [x] 5.2 Remove `changeAnswerSize := ChangeAnswerSizeCommand(sess)` instantiation from `App.__New()`
- [x] 5.3 Remove `changeAnswerSize` argument from `SettingsController(...)` constructor call in `App.__New()`

## 6. Verification

- [x] 6.1 Run `grep -rni "answersize\|answer.size\|answer_size" --include="*.ahk" .` to verify zero remaining references in code
- [x] 6.2 Launch `main.ahk` and verify: menu bar has exactly 4 entries (File, Session, Tools, Model) with no "Answer Size", all other menus work normally
- [x] 6.3 Send a message to an LLM and verify the response is received correctly (no verbosity instruction injected)
