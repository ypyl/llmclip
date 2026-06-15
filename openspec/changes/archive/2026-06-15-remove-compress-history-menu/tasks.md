## 1. View Layer — Remove History menu and compression UI

- [x] 1.1 Remove `historyMenu` field, `historyMenu.Add("Compress", ...)` block, `menuBar.Add("History", ...)` line, and `UpdateCompressionState()` method from `ui/MenuView.ahk`
- [x] 1.2 Remove `this.settingsController.UpdateCompressionMenuState()` call from `MainView.BuildUI()` in `ui/MainView.ahk`

## 2. Controller Layer — Remove compression coordination

- [x] 2.1 Remove `compressHistoryCommand` field, `compress` param from `SetCommands()`, `CompressHistory()` method, and `COMPRESSING` branch from `SetProcessingState()` in `Controllers/MainController.ahk`
- [x] 2.2 Remove `getCompressionStateCommand` field, constructor param, `UpdateCompressionMenuState()` method, and its calls in `SelectModel()` and `ReloadSettings()` from `Controllers/SettingsController.ahk`

## 3. Command Layer — Delete compress commands

- [x] 3.1 Delete `Commands/CompressHistoryCommand.ahk`
- [x] 3.2 Delete `Commands/GetCompressionMenuStateCommand.ahk`

## 4. Service Layer — Remove compress methods

- [x] 4.1 Remove `CompressHistory()` method from `Services/LLM/LLMService.ahk`
- [x] 4.2 Remove `FormatMessagesForCompression()`, `FormatMessagesForCompressionForSession()`, `ReplaceWithCompressed()`, `ReplaceWithCompressedForSession()` from `Services/SessionManager.ahk`
- [x] 4.3 Remove `GetCompressionPrompt()` method from `Services/Configuration/ConfigurationService.ahk`
- [x] 4.4 Remove `COMPRESSING` constant from `Services/ProcessingState.ahk`

## 5. Composition Root — Clean up App.ahk wiring

- [x] 5.1 Remove `#Include Commands\CompressHistoryCommand.ahk` and `#Include Commands\GetCompressionMenuStateCommand.ahk` from `App.ahk`
- [x] 5.2 Remove `compress` and `getCompressionState` command instantiations from `App.__New()`
- [x] 5.3 Remove `compress` from `SetCommands()` call and `getCompressionState` from `SettingsController` constructor call in `App.__New()`

## 6. Spec & Documentation Cleanup

- [x] 6.1 Delete `openspec/specs/compression-service/` directory (the live spec, not the change delta)
- [x] 6.2 Remove "Compression: Summarize long conversations..." bullet from `README.md` History Management section

## 7. Verification

- [x] 7.1 Run `grep -rni "compress" --include="*.ahk" .` to verify zero remaining references to compress in code
- [x] 7.2 Launch `main.ahk` and verify: menu bar has no History entry, all other menus (File, Session, Mode, Tools, Answer Size, Model) work normally, chat-history ListView (Delete/Copy/`<`/`>`/Clear) functions normally
