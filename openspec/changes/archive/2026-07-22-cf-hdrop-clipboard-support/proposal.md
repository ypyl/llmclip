## Why

Copying files/folders from VSCode's Explorer pane places file paths on the Windows clipboard in a format that stores bare Windows paths — no `file:///` prefix. The current `ClipboardParserHelper` only scans raw clipboard bytes for `file:///` patterns, so it silently misses these files. On machines where VSCode does not additionally emit a `text/uri-list` format, copying files during recording adds nothing to context. The paths are present in the raw clipboard data (visible as garbled `aA.C:\Users\...` after null-byte stripping), just without the URI prefix.

## What Changes

- Add a drive-letter regex scan (`[A-Za-z]:\`) on the raw `ClipboardAll()` byte data as a fallback when the `file:///` URI scan yields no results
- Walk backwards character-by-character from the candidate string until `FileExist` or `DirExist` succeeds, stripping trailing garbage from the raw byte stream
- The `file:///` URI scan remains as the first attempt; the drive-letter scan runs only when no URIs are found

## Capabilities

### New Capabilities
<!-- None — this extends existing clipboard parsing, no new capability area -->

### Modified Capabilities
- `clipboard-processing`: `ClipboardParserHelper.Parse()` gains a bare drive-letter path fallback, covering the scenario where clipboard file paths lack `file:///` URIs

## Impact

- **Affected code**: `Utils/ClipboardParserHelper.ahk` only — ~15 lines added to `Parse()`, no new methods
- **Architecture**: Utility layer (static helpers), no new dependencies, no `App.ahk` wiring changes
- **No breaking changes**: existing behavior unchanged; drive-letter scan is additive
- **No new dependencies**: uses only `RegExMatch`, `FileExist`/`DirExist` (all built-in AHK v2)
