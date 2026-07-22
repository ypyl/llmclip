## Why

Copying files/folders from VSCode's Explorer pane (and potentially other applications) places file paths on the Windows clipboard using the `CF_HDROP` native format — which stores bare Windows paths, not `file:///` URIs. The current `ClipboardParserHelper` only scans raw clipboard bytes for `file:///` patterns, so it silently misses these files. On machines where VSCode does not additionally emit a `text/uri-list` format, copying files during recording adds nothing to context.

## What Changes

- Add `CF_HDROP` (format 15) file-path extraction as a fallback in `ClipboardParserHelper.Parse()` when the `file:///` URI scan yields no results
- Use Windows API calls (`OpenClipboard` → `GetClipboardData` → `DragQueryFile`) to reliably extract paths — correct encoding handled by the OS, no byte-guessing
- The `file:///` URI scan remains as the first attempt; CF_HDROP is a secondary path that runs only when no URIs are found

## Capabilities

### New Capabilities
<!-- None — this extends existing clipboard parsing, no new capability area -->

### Modified Capabilities
- `clipboard-processing`: `ClipboardParserHelper.Parse()` gains CF_HDROP fallback extraction, covering the scenario where clipboard file paths are stored in native Windows format without `file:///` URIs

## Impact

- **Affected code**: `Utils/ClipboardParserHelper.ahk` only — new static method(s) for CF_HDROP extraction, called from `Parse()` as a fallback
- **Architecture**: Utility layer (static helpers), no new dependencies, no `App.ahk` wiring changes
- **No breaking changes**: existing behavior unchanged; CF_HDROP extraction is additive
- **No new dependencies**: uses only `DllCall` (built-in AHK v2) and standard Windows shell32 API
