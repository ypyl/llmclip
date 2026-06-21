## Context

`MenuView` currently owns a static `ToolMapping` array that defines the complete tool roster — tool IDs, display labels, and state key mappings. This is the only place in the codebase where tool display labels exist. The array references tool class constants (`PowerShellTool.TOOL_NAME`, etc.) from `services/LLM/`, creating an implicit dependency from the View layer to the Service layer. The View receives tool state as a magic object (`{execute_powershell: bool, ...}`) and uses `ToolMapping` to decode it.

Adding a new tool currently requires updating `MenuView.ToolMapping` (the View), `GetToolsMenuStateCommand`, `ExecuteToolCallsCommand`, `SendToLLMCommand`, `LLMService`, and three provider files — seven locations. This change targets the View coupling specifically; the command/provider duplications remain separate concerns.

The existing model and session menus already follow the correct pattern: `MainController` exposes `ModelDisplayNames` and `SessionLabels` as data properties, and `MenuView.Create()` receives them as parameters. The tools menu should follow the same pattern.

## Goals / Non-Goals

**Goals:**
- Remove `static ToolMapping` from `MenuView` — the View receives tool definitions as data
- Make each tool class own its display label via `static TOOL_LABEL`
- Derive the tool roster from `App.ahk`'s `toolsMap` (single source of truth)
- Make `GetToolsMenuStateCommand` data-driven (receives tool defs, returns `[{label, checked}]`)
- Preserve exact same menu rendering and behavior — zero user-visible change

**Non-Goals:**
- Removing tool list duplication in `ExecuteToolCallsCommand`, `SendToLLMCommand`, `LLMService`, or providers (separate issues)
- Changing the tool enablement storage model (`tool-persistence` spec is unaffected)
- Altering the Tools menu's visual appearance or interaction behavior
- Adding/removing tools

## Decisions

### Decision 1: Add `static TOOL_LABEL` to each tool class

**Rationale**: The display label is a property of the tool itself, not a UI concern. Putting it on the tool class follows the same pattern as `TOOL_NAME`. It lets `App.ahk` derive labels from the `toolsMap` without needing a separate mapping.

**Alternatives considered**:
- Keep labels only in a central definition array in `App.ahk` — would work, but means the label is divorced from the tool class that owns the behavior. A developer adding a new tool would need to define the label in two places (the class for `TOOL_NAME`, App.ahk for the label). Putting both on the class keeps them together.
- Add labels to `providers.json` — overkill; labels are UI presentation, not provider configuration.

### Decision 2: Derive `toolDefs` from `toolsMap` in `App.ahk`

**Rationale**: The `toolsMap` is already the runtime registry of tool instances. Deriving `[{id, label}]` from it means the tool roster is defined in exactly one place (the map insertion). AHK v2 Maps preserve insertion order, so the resulting array maintains the same order as `App.ahk`'s `toolsMap`.

**Alternatives considered**:
- Hardcode a separate `toolDefs` array in `App.ahk` — duplicates the tool list; the `toolsMap` insertion and the `toolDefs` array could get out of sync.
- Put `toolDefs` in `ConfigurationService` — tools are instantiated in `App.ahk`, not configured. ConfigurationService manages provider/model/settings data, not runtime tool instances.

### Decision 3: `GetToolsMenuStateCommand` returns `[{label, checked}]` instead of `{execute_powershell: bool, ...}`

**Rationale**: The command currently returns an object with magic keys that only the View (via `ToolMapping`) knows how to decode. Returning a labeled array makes the data self-describing — the View can render it without any internal mapping. This also makes the command testable in isolation (the output tells you what it means).

**Alternatives considered**:
- Keep the current object format and just move `ToolMapping` to the controller — simpler but doesn't solve the core problem of the View needing a decoder ring for tool state data.
- Return `[{id, label, checked}]` — includes the tool ID, but the View doesn't need IDs; labels are the native key for AHK's `Menu.Check()`/`Menu.Uncheck()` API. Extra data is noise.

### Decision 4: `MainController` exposes `ToolDefinitions` property (same pattern as `ModelDisplayNames`, `SessionLabels`)

**Rationale**: Consistency with existing patterns. `MainView.BuildUI()` already reads `this.controller.ModelDisplayNames` and `this.controller.SessionLabels` to pass to `MenuView.Create()`. Adding `this.controller.ToolDefinitions` follows the established convention. This also means the tool definitions flow through the controller layer (as they should) rather than `MainView` accessing `App.ahk` directly.

### Decision 5: `ToggleTool` callback binding stays in `MenuView.Create()`

**Rationale**: The current code binds `ObjBindMethod(settingsController, "ToggleTool", toolInfo.id)` in `MenuView.Create()`. With the new design, the View still receives `[{id, label}]` and uses `id` to bind the callback. The View knows the tool ID only as an opaque value for the callback — it doesn't interpret it. This keeps the View simple (no pre-bound callbacks from the controller) while still being data-driven.

**Alternative considered**: Controller pre-binds callbacks and the View receives `[{label, callback}]`. Cleaner separation but requires `SettingsController` to build callback objects, adding indirection with no practical benefit since the View never interprets the ID.

## Risks / Trade-offs

- **[Risk] AHK v2 Map iteration order**: We rely on `toolsMap` preserving insertion order for tool menu ordering. Mitigation: AHK v2 Maps are insertion-ordered by spec. If this changes in a future AHK version, the fix is to use an explicit ordered definition (backup array in `App.ahk`).
- **[Risk] Tool class not having `TOOL_LABEL`**: If a tool is added to `toolsMap` without a `TOOL_LABEL` static, the `App.ahk` derivation will fail at runtime. Mitigation: This is a development-time concern — all 6 tools are being updated in this change, and the pattern is simple enough to follow for future tools.
