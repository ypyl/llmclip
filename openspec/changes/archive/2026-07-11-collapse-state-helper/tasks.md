## 1. StateHelper — collapse save/load duplication

- [x] 1.1 Add `Save(path, obj)` and `Load(path)` static methods containing the shared logic
- [x] 1.2 Refactor `SaveState` and `SaveConversation` to one-line delegates calling `Save`
- [x] 1.3 Refactor `LoadState` and `LoadConversation` to one-line delegates calling `Load`

## 2. Integration check

- [x] 2.1 Run `main.ahk`, verify state/conversation persistence works (save on exit, load on start)
