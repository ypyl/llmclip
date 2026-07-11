## Why

Users have no way to check which version of the app they're running. This matters for bug reports, feature awareness, and confirming the latest release is installed. Adding a version display to the top-right corner of the window provides immediate visibility without additional UI chrome.

## What Changes

- Create `version.txt` at repo root containing the current version string (`1.3.4`)
- Read version in `App.ahk`, pass it to `MainView` during construction
- Add a `Text` control in `MainView.BuildUI` at the top-right of the window showing the version
- Reposition the version label on window resize

## Capabilities

### New Capabilities
- `app-version-display`: App displays its version in the top-right corner of the window

### Modified Capabilities
<!-- None -->

## Impact

- **New file**: `version.txt` — single line with version
- **Modified**: `App.ahk` (read version, pass to MainView), `MainView.ahk` (display version label, update on resize)
- **CI**: No changes — `version.txt` is a manual update (can be automated later)
- **No behavior change**: purely cosmetic addition
