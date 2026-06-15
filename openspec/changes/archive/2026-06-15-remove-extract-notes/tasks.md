## 1. Delete feature files

- [x] 1.1 Delete `Commands/ExtractLearningsCommand.ahk`
- [x] 1.2 Delete `Controllers/NotesController.ahk`
- [x] 1.3 Delete `ui/NotesView.ahk`

## 2. Clean up Services layer

- [x] 2.1 Remove `ExtractLearnings()` method from `Services/LLM/LLMService.ahk`
- [x] 2.2 Remove `GetLearningsPrompt()` method from `Services/Configuration/ConfigurationService.ahk`
- [x] 2.3 Remove `static EXTRACTING` constant from `Services/ProcessingState.ahk`

## 3. Clean up Controllers

- [x] 3.1 Remove `extractLearningsCommand` field, SetCommands parameter, and `ExtractLearnings()` method from `Controllers/MainController.ahk`
- [x] 3.2 Remove `notesController` field and SetSubControllers wiring from `Controllers/MainController.ahk`
- [x] 3.3 Remove `EXTRACTING` else-if branch from `SetProcessingState()` in `Controllers/MainController.ahk`

## 4. Clean up UI and Composition Root

- [x] 4.1 Remove "Extract Notes" menu item from `ui/MenuView.ahk`
- [x] 4.2 Remove 3 `#Include` directives from `App.ahk` (NotesController, ExtractLearningsCommand, NotesView)
- [x] 4.3 Remove `ExtractLearningsCommand` instantiation from `App.ahk`
- [x] 4.4 Remove `NotesView`/`NotesController` instantiation and wiring from `App.ahk`
- [x] 4.5 Remove `extract` and `notesContr` parameters from `SetCommands` and `SetSubControllers` calls in `App.ahk`

## 5. Verification

- [x] 5.1 Verify no remaining references to removed symbols by searching codebase for: `ExtractLearnings`, `ExtractLearningsCommand`, `NotesController`, `NotesView`, `GetLearningsPrompt`, `EXTRACTING`, `extractLearningsCommand`, `notesController`, `notesViewInstance`
- [x] 5.2 Run `main.ahk` and confirm the app launches without errors, History menu has no "Extract Notes" item, and all other functionality works normally
