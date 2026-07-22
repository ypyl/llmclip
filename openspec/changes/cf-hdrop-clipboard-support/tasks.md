## 1. CF_HDROP extraction helper

- [x] 1.1 Add static `ExtractFromCFHDrop()` method to `ClipboardParserHelper` that opens the clipboard, retrieves CF_HDROP data, queries file count via `DragQueryFile(hDrop, -1, ...)`, then iterates and extracts each path via `DragQueryFile(hDrop, i, buf, size)`. Close clipboard handle on all exit paths (success and failure). Return an array of path strings, or empty array on any failure.

## 2. Integrate fallback into Parse()

- [x] 2.1 In `Parse()`, after the `file:///` URI while-loop, if `localTxtFromClipboardArray` is still empty (no URIs found), call `this.ExtractFromCFHDrop()`. If it returns paths, use them as the result array. If it returns empty, fall through to the existing plain-text fallback.

## 3. Verification

- [ ] 3.1 Run `main.ahk`, start recording, copy a file from VSCode Explorer pane, verify the file path appears in the context list. Also verify plain text copy and Windows Explorer file copy still work.
