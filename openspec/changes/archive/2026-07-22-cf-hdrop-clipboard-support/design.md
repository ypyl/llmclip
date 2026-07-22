## Context

`ClipboardParserHelper.Parse()` currently handles three clipboard sources:

1. **Plain text** (`A_Clipboard`) — works universally
2. **File URI scan** — reads raw `ClipboardAll()` bytes, skips nulls, searches for `file:///`. This handles VSCode when it emits `text/uri-list` with URIs.
3. **Image** — delegates to `ClipboardImageHelper`

The URI scan (2) fails when VSCode places file paths without `file:///` prefix. The raw `ClipboardAll()` bytes DO contain the path — visible as `aA.C:\Users\...` after null-byte stripping — but the byte-level encoding and DROPFILES header mangle the prefix, so `file:///` is never found.

A previous attempt used `DllCall` with `GetClipboardData(CF_HDROP)` + `DragQueryFile`, but `GetClipboardData(15)` consistently returned 0 on the target machine — the format isn't available as CF_HDROP this way.

The working fix: after the `file:///` scan finds nothing, scan the already-built `rawData` string for bare Windows drive-letter patterns (`[A-Za-z]:\`) and validate with `FileExist`/`DirExist`.

## Goals / Non-Goals

**Goals:**
- Extract bare Windows paths from `rawData` when `file:///` URI scan fails
- Zero external API dependencies — pure AHK v2 built-ins
- Zero impact on existing behavior
- No changes outside `ClipboardParserHelper.ahk`

**Non-Goals:**
- Parsing the DROPFILES structure correctly (not needed — the path is already extractable)
- Other clipboard formats — just the drive-letter fallback
- Perfect multi-file extraction (the URI scan handles that case; drive-letter scan covers single-file copies)

## Decisions

### Decision 1: Regex drive-letter scan on rawData, not clipboard API

**Choice**: Scan the already-built `rawData` string for `[A-Za-z]:\` patterns, then walk backwards from end-of-string trimming characters until `FileExist`/`DirExist` succeeds.

**Rationale**: `GetClipboardData(CF_HDROP)` always returned 0 — the format is present in the raw byte stream but not accessible as a discrete clipboard format via the API. The path data is already in `rawData` (the byte-by-byte Chr() string), just preceded by garbled DROPFILES header bytes. Since VSCode file copies are single-file, we can take everything from the first drive letter to end-of-string, then trim trailing garbage. Simpler, fewer moving parts, and actually works.

**Alternative considered**: `DllCall` with `OpenClipboard`/`GetClipboardData`/`DragQueryFile`. This was implemented and tested — `GetClipboardData(15)` consistently returned 0, so it was removed as dead code.

### Decision 2: Trail-trimming validation, not regex extraction

**Choice**: Extract from drive letter to end of string, then loop `SubStr(candidate, 1, -1)` until `FileExist` or `DirExist` passes.

**Rationale**: We don't know where the path ends in the byte stream — after the path there may be more DROPFILES data, another path, or binary garbage. The simplest validation is the OS itself: keep chopping from the end until the path actually exists on disk. This handles all encoding edge cases for free.

**Alternative considered**: Regex to capture valid path characters. Rejected — Windows allows Unicode, spaces, and many special chars in paths; writing a correct regex is fragile. Let the OS do the validation.

### Decision 3: Error handling — silent fallback

**Choice**: If the drive-letter scan finds nothing valid, silently fall back to the original text result. No MsgBox, no error.

**Rationale**: Background clipboard hook. The worst case is identical to today: the file isn't captured.

## Risks / Trade-offs

- **Risk**: False positive — `rawData` contains a drive-letter pattern that isn't a copied file path (e.g., a C:\ reference in unrelated binary data) → **Mitigation**: `FileExist`/`DirExist` validation ensures we only return paths that actually exist on disk. Very unlikely to match a non-path string.
- **Risk**: Long paths (>260 chars) truncated in buffer → **Mitigation**: `ClipboardAll()` captures the full data; the byte scan processes the entire buffer. The trail-trimming loop works on the full string.
- **Trade-off**: Multi-file copies from VSCode would only capture the first file. In practice, VSCode file copies are almost always single-file, and multi-file falls through to the URI scan on machines where that works.
