## 1. Controller cleanup

- [x] 1.1 Remove `SetSaveEditCallback` call from `HistoryViewController.__New()` — delete the 3-line `if (this.webViewManager) { ... }` block

## 2. Composition root wiring

- [x] 2.1 Add `wv.SetSaveEditCallback(ObjBindMethod(histView, "OnMessageEdited"))` to `App.ahk` immediately after the `histView` construction line

## 3. Verification

- [x] 3.1 Run `main.ahk` and smoke-test: open a conversation, edit a message in the WebView response area, confirm the edit saves back to the session history
