## ADDED Requirements

### Requirement: Tool classes own their display label
Each tool class in `services/LLM/` SHALL define a `static TOOL_LABEL` constant containing the human-readable display name used in the Tools menu.

#### Scenario: PowerShell tool has a label
- **WHEN** `PowerShellTool.TOOL_LABEL` is accessed
- **THEN** it SHALL return `"PowerShell"`

#### Scenario: FileSystem tool has a label
- **WHEN** `FileSystemTool.TOOL_LABEL` is accessed
- **THEN** it SHALL return `"File System"`

#### Scenario: All tool classes define TOOL_LABEL
- **WHEN** any tool class is instantiated and added to `toolsMap` in `App.ahk`
- **THEN** that class SHALL have `static TOOL_LABEL` defined alongside `static TOOL_NAME`

### Requirement: Tool roster is derived from toolsMap in App.ahk
The `App.ahk` composition root SHALL derive a `toolDefs` array from the `toolsMap` after all tools are instantiated. Each element SHALL be `{id: <TOOL_NAME>, label: <TOOL_LABEL>}`.

#### Scenario: toolDefs matches toolsMap entries
- **WHEN** `App.__New()` instantiates all tools and builds `toolsMap`
- **THEN** `toolDefs` SHALL contain exactly one entry per tool in `toolsMap`
- **AND** entries SHALL appear in `toolsMap` insertion order

#### Scenario: Adding a tool to toolsMap automatically includes it in toolDefs
- **WHEN** a new tool instance is added to `toolsMap` in `App.ahk`
- **AND** the tool class defines `static TOOL_NAME` and `static TOOL_LABEL`
- **THEN** the tool SHALL appear in `toolDefs` without any additional changes to `MenuView` or `MainView`

### Requirement: GetToolsMenuStateCommand is data-driven
`GetToolsMenuStateCommand` SHALL receive `toolDefs` as a constructor dependency and return an array of `{label: <string>, checked: <bool>}` from its `Execute()` method. It SHALL NOT hardcode references to individual tool classes or their `TOOL_NAME` constants.

#### Scenario: Command returns labeled state for all tools
- **WHEN** `GetToolsMenuStateCommand.Execute()` is called with `toolDefs` containing `[{id: "file_system", label: "File System"}]`
- **AND** `IsToolEnabled` returns `true` for `"file_system"`
- **THEN** the result SHALL be `[{label: "File System", checked: true}]`

#### Scenario: Command returns checked=false for disabled tool
- **WHEN** `GetToolsMenuStateCommand.Execute()` is called
- **AND** `IsToolEnabled` returns `false` for a given tool
- **THEN** that tool's entry SHALL have `checked: false`

#### Scenario: Command does not reference tool class constants
- **WHEN** `GetToolsMenuStateCommand.ahk` is examined
- **THEN** it SHALL NOT contain references to `PowerShellTool.TOOL_NAME`, `FileSystemTool.TOOL_NAME`, or any other tool class constant

### Requirement: MenuView receives tool definitions as data
`MenuView` SHALL NOT define a static `ToolMapping` array. `MenuView.Create()` SHALL accept a `toolDefs` parameter (`[{id, label}]`) and use it to build the Tools menu items. `MenuView.UpdateToolsMenu()` SHALL accept a `toolStates` parameter (`[{label, checked}]`) and use it to update checkmarks.

#### Scenario: MenuView builds tools menu from provided definitions
- **WHEN** `MenuView.Create()` is called with `toolDefs := [{id: "execute_powershell", label: "PowerShell"}, {id: "file_system", label: "File System"}]`
- **THEN** the Tools menu SHALL contain two items labeled "PowerShell" and "File System"
- **AND** each item SHALL be bound to `settingsController.ToggleTool(<id>)`

#### Scenario: MenuView updates checkmarks from provided states
- **WHEN** `MenuView.UpdateToolsMenu()` is called with `[{label: "PowerShell", checked: true}, {label: "File System", checked: false}]`
- **THEN** the "PowerShell" menu item SHALL be checked
- **AND** the "File System" menu item SHALL be unchecked

#### Scenario: MenuView has no static ToolMapping
- **WHEN** `MenuView.ahk` is examined
- **THEN** it SHALL NOT contain `static ToolMapping`

### Requirement: MainController exposes ToolDefinitions property
`MainController` SHALL expose a `ToolDefinitions` property that returns the `toolDefs` array received during construction, following the same pattern as `ModelDisplayNames` and `SessionLabels`.

#### Scenario: MainController receives and exposes tool definitions
- **WHEN** `MainController` is constructed with `toolDefs := [{id: "...", label: "..."}]`
- **THEN** `MainController.ToolDefinitions` SHALL return that same array

### Requirement: MainView passes tool definitions to MenuView
`MainView.BuildUI()` SHALL read `this.controller.ToolDefinitions` and pass it to `menuView.Create()` as the `toolDefs` parameter.

#### Scenario: Tool definitions flow from controller to view
- **WHEN** `MainView.BuildUI()` calls `this.menuView.Create(...)`
- **THEN** the call SHALL include `this.controller.ToolDefinitions` as an argument
