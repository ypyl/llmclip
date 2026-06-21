## Why

`MenuView` (a View — structure-only layer) currently owns a static `ToolMapping` array that defines the entire tool roster: which tools exist, what they're called, and how state keys map to labels. This hardcoded list creates a hidden dependency from the UI layer to the service layer (tool class constants), duplicates the tool roster across 7 files, and means adding a tool requires touching both the composition root AND the View. The View should receive tool data, not define it.

This was identified as issue #6 in the ARCHITECTURE_REVIEW.md — a 🟡 SMELL with the highest remaining priority after all critical/structural fixes were completed.

## What Changes

- Each tool class gains a `static TOOL_LABEL` constant alongside its existing `TOOL_NAME`, making the tool own its display name
- `App.ahk` derives a single `toolDefs` array from the `toolsMap` (composition root becomes the single source of truth for the tool roster)
- `GetToolsMenuStateCommand` becomes data-driven: receives `toolDefs`, returns `[{label, checked}]` instead of a hardcoded object with magic keys
- `MenuView` receives tool definitions as a parameter to `Create()` and `[{label, checked}]` arrays for `UpdateToolsMenu()` — no more static `ToolMapping`, no more references to tool class constants
- `MainView.BuildUI()` passes tool definitions from the controller through to `MenuView.Create()`
- `MainController` stores and exposes `ToolDefinitions` (same pattern as `ModelDisplayNames` and `SessionLabels`)

## Capabilities

### New Capabilities

- `tool-presentation`: How tools are presented in the menu bar — the View receives tool definitions as data and renders them without knowing tool internals. Adding a tool means adding its class + one line in `App.ahk`; no View changes needed.

### Modified Capabilities

<!-- No existing spec requirements change. tool-persistence spec (storage/retrieval of tool enablement state) is unaffected — this change only alters the data flow for displaying tools in the UI. -->

## Impact

- **12 files touched**: 6 tool classes (one line each), `App.ahk`, `MainController.ahk`, `GetToolsMenuStateCommand.ahk`, `MenuView.ahk`, `MainView.ahk`, and `SettingsController.ahk` (trivial passthrough)
- **No breaking changes**: Tool class constants (`TOOL_NAME`) are unchanged. The `toolsMap` in `App.ahk` is unchanged. `ToggleToolCommand`, `ExecuteToolCallsCommand`, `SendToLLMCommand`, `LLMService`, and all providers are unaffected.
- **Removes implicit dependencies**: `MenuView` no longer transitively depends on tool class files being included before it
- **Zero behavioral change**: The tools menu renders identically; only the internal data path changes
