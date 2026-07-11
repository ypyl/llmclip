## Context

The app window is 1230×610 with a native AHK MenuBar at the top. Below the menu bar, a WebView2 control fills most of the right side (response area), with context, prompt, and history controls on the left. There's unused space at the top-right corner — the menu bar extends full width but only 4 items use the left portion.

The project uses git tags for releases (`v1.3.4`). There's currently no version file or runtime version awareness.

## Goals / Non-Goals

**Goals:**
- Show version string in top-right corner of the window
- Keep it unobtrusive (small text, no interaction)
- Survive window resize (reposition)

**Non-Goals:**
- No click-to-copy or interaction
- No auto-detection from git tags (just reads a file)
- No update check or notification

## Decisions

**Decision 1: Store version in `version.txt`.**

Alternatives: embed in source constant (easy to forget updating), read from git tags at build time (complex, only works in CI). A plain text file is the simplest — one line, easy to update before release, easy to read at runtime.

**Decision 2: Display via Gui.Text control, not MenuBar.**

AHK v2 MenuBar has no right-alignment. Adding a 5th menu bar item would appear next to the 4th, not at the right edge. A `Text` control with absolute positioning gives precise top-right placement.

Position: `x` = window width − 80px, `y` = 2px (top edge, just below or alongside the menu bar). On resize, reposition to `W − 80`.

**Decision 3: Pass version from App.ahk through constructor.**

`App.ahk` reads `version.txt` → passes to `MainView` constructor → `MainView` creates the text control. Keeps file I/O in the composition root and the View pure (zero logic — just creates the control with the provided string).

## Risks / Trade-offs

- **Manual version.txt updates**: Risk of version.txt going stale. Mitigation: CI can write it during release build (future enhancement). For now, it's one line to update.
- **Overlap on narrow window**: At `minWidth` (800px), the version text at `x=720` won't overlap any existing controls (history is further left at ~400).
