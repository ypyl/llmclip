## Why

`HistoryViewController.__New()` calls `this.webViewManager.SetSaveEditCallback(...)`, which mutates `WebViewManager` (a Service). The architecture mandates that **Controllers can read services, never mutate them**. Service wiring belongs in `App.ahk`, the composition root, following the identical post-construction property-assignment pattern already used for Views and other Controllers throughout the codebase. This is the last remaining 🟠 architecture violation identified in the ARCHITECTURE_REVIEW.md.

## What Changes

- Remove the `SetSaveEditCallback` call from `HistoryViewController.__New()`
- Add the equivalent call to `App.ahk` after `HistoryViewController` construction, following established wiring patterns

## Capabilities

### New Capabilities

None — this is a structural refactor with zero behavioral change.

### Modified Capabilities

None — no spec-level requirements change.

## Impact

- **`controllers/HistoryViewController.ahk`**: Remove 3 lines from constructor
- **`App.ahk`**: Add 1 line of wiring after `histView` construction
- No API, dependency, or behavioral changes
