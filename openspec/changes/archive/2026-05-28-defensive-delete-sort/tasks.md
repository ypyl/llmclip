## 1. Implementation

- [x] 1.1 Add `_SortDescending()` method to `DeleteMessageCommand` (or inline the sort logic) that sorts an array of integers in descending order
- [x] 1.2 Call the sort on `selectedIndices` at the start of `Execute()`, before the removal loop

## 2. Verification

- [x] 2.1 Manual smoke test: launch `main.ahk`, send several messages, multi-select and delete them, verify correct messages are removed (needs manual AHK v2 execution)
