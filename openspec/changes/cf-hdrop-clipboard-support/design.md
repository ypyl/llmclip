## Context

`ClipboardParserHelper.Parse()` currently handles three clipboard sources:

1. **Plain text** (`A_Clipboard`) — works universally
2. **File URI scan** — reads raw `ClipboardAll()` bytes, skips nulls, searches for `file:///`. This handles VSCode when it emits `text/uri-list` with URIs.
3. **Image** — delegates to `ClipboardImageHelper`

The URI scan (2) fails when VSCode (or other apps) place file paths in `CF_HDROP` format (native Windows drag-drop, format ID 15). `CF_HDROP` uses a `DROPFILES` structure with bare paths — no `file:///` prefix. The byte-guessing (`Chr()` on raw bytes) also mangles the DROPFILES header into garbage characters.

The fix is a proper `CF_HDROP` extraction using Windows shell32 API, called as a fallback when the URI scan produces nothing.

## Goals / Non-Goals

**Goals:**
- Extract file paths from `CF_HDROP` clipboard format when `file:///` URI scan fails
- Use Windows API so encoding (ANSI vs UTF-16) is handled by the OS — no byte-guessing
- Zero impact on existing behavior when CF_HDROP is not present
- No changes outside `ClipboardParserHelper.ahk`

**Non-Goals:**
- Other clipboard formats beyond CF_HDROP (format 15)
- Non-VSCode-specific logic — the fallback runs regardless of active window
- Changing the `file:///` URI path (it still runs first)

## Decisions

### Decision 1: Fallback strategy — CF_HDROP after URI scan, not instead of

**Choice**: Keep the `file:///` URI scan as-is, add CF_HDROP extraction as a secondary path that runs only when no URIs were found.

**Rationale**: The URI scan has proven reliable when `file:///` is present (which depends on VSCode version/config). CF_HDROP handles the missing case. Running both in sequence is simpler than trying to detect which format will be present upfront. The URI scan is cheap (string search on a small buffer).

**Alternative considered**: Replace the raw-byte approach entirely with proper clipboard format enumeration. Rejected — larger change, and the URI scan does work on many machines.

### Decision 2: Use DllCall directly, not a new Lib dependency

**Choice**: Call `OpenClipboard`, `GetClipboardData`, `DragQueryFile` (from shell32.dll) via AHK v2 `DllCall` inline in `ClipboardParserHelper`.

**Rationale**: These are 3 simple API calls. Adding a Lib wrapper for this would be over-engineered. The `Lib/` directory is vendored and must not be modified. The calls are well-documented Win32 API and trivial to implement correctly.

**Alternative considered**: A new helper class in `Utils/`. Rejected — a single static method on `ClipboardParserHelper` is sufficient; the logic is ~20 lines.

### Decision 3: Encoding handling — let the OS decide

**Choice**: Call `DragQueryFile` with a buffer and let it return the path in the system's native encoding. No manual Unicode/ANSI detection.

**Rationale**: The `fWide` flag in DROPFILES tells us the encoding, but `DragQueryFile` abstracts this away — it always returns a properly encoded string for the current system. We don't need to parse the DROPFILES structure at all.

### Decision 4: Error handling — silent fallback

**Choice**: If CF_HDROP extraction fails (clipboard locked, no HDROP data, etc.), silently return the original text-only result. No error messages, no MsgBox.

**Rationale**: This is a background clipboard hook. Popping up error dialogs during normal copy operations is unacceptable UX. The worst case is the same as today: the file path isn't captured.

## Risks / Trade-offs

- **Risk**: Opening the clipboard with `OpenClipboard` may briefly conflict with other apps reading the clipboard simultaneously → **Mitigation**: The call is instantaneous (open → get data → close); standard Windows clipboard etiquette. All apps do this.
- **Risk**: `DragQueryFile` may return paths in short (8.3) format on some configurations → **Mitigation**: Test on target machine after implementation; if observed, add `GetLongPathName` call.
- **Trade-off**: The fallback runs for ALL apps, not just VSCode. This is intentional — any app using CF_HDROP (File Explorer, Total Commander, etc.) benefits.
