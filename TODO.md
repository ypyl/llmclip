# Ponytail Audit Todos

Findings from the repo-wide over-engineering audit (2026-08-05). Ranked by cut size — do them top-down. Each item is independent; tick it off when done.

**Net potential:** -400 lines, 0 deps

- [x] 1. `delete:` Remove `SystemPrompts.UpdatePrompt()` — the ~245-line rename/migrate/metadata method (incl. `SanitizeFileName` and its 4x-duplicated "find the JSON file" loops). Zero callers since the prompt-editor tools were removed. Keep `UpdatePromptValue` (1 live caller). [Services/Configuration/SystemPrompts.ahk:89-329]
- [x] 2. `delete:` Remove dead members in `Types.ahk`: `ChatContent.Type` field (write-only — every read site uses `is`), `ChatContent` base class (no `is ChatContent` checks anywhere), all `Clone()` methods (never called outside their own recursion), `ChatMessage.AddImage` (0 callers). [Services/LLM/Types.ahk]
- [x] 3. `delete:` Remove dead methods in `SessionManager`: `UpdateMessage`, `IsToolCallExecuted`, `HasToolResponse`, `HasAnyCheckedItem`, `GetMessageText` (0 callers each), `HasVal` (0 callers — `PrepareContextCommand` has its own private copy). [Services/SessionManager.ahk]
- [ ] 4. `shrink:` Collapse Map↔Object dual-path deserialization: drop every `isMap ? obj.Has("x") : obj.HasOwnProp("x")` branch in `Session.FromObject`/`ContextItem.FromObject`/`ImportSessionState`, plus `ConvertMapToObject` and the `convertMapFunc` plumbing in `History.FromObject`. The JSON lib returns `Map` and `JSON.Stringify` accepts it — Map-only end to end. **Careful pass: touches the persistence path.** [Services/Session.ahk, Services/SessionManager.ahk, Services/History.ahk, Services/ContextItem.ahk]
- [ ] 5. `shrink:` Merge `OnToggleRecording` into `ToggleDisplay` (identical 3-branch recording/show/stop logic). One method with the null guard; record button and tray/hotkey call the same one. [Controllers/MainController.ahk:91-96 vs 194-200]
- [ ] 6. `delete:` Remove `MainController.view` field — "backward compat during migration" shim, written in `SetView`, never read. [Controllers/MainController.ahk:104]
- [ ] 7. `shrink:` Make `StateHelper.Save/Load` delegate to `FileHelper.WriteText`/`ReadText` instead of re-implementing them. [Utils/StateHelper.ahk]
