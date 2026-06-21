## 1. Tool Classes — Add TOOL_LABEL

- [x] 1.1 Add `static TOOL_LABEL := "PowerShell"` to `services/LLM/PowerShellTool.ahk`
- [x] 1.2 Add `static TOOL_LABEL := "File System"` to `services/LLM/FileSystemTool.ahk`
- [x] 1.3 Add `static TOOL_LABEL := "Web Search"` to `services/LLM/WebSearchTool.ahk`
- [x] 1.4 Add `static TOOL_LABEL := "Web Fetch"` to `services/LLM/WebFetchTool.ahk`
- [x] 1.5 Add `static TOOL_LABEL := "Read URL Markdown"` to `services/LLM/MarkdownNewTool.ahk`
- [x] 1.6 Add `static TOOL_LABEL := "Create Prompt"` to `services/LLM/PromptCreatorTool.ahk`

## 2. Composition Root — Update App.ahk

- [x] 2.1 Derive `toolDefs` array from `toolsMap` after tool instantiation: `for id, tool in toolsMap` → `toolDefs.Push({ id: id, label: tool.TOOL_LABEL })`
- [x] 2.2 Pass `toolDefs` to `GetToolsMenuStateCommand` constructor: `GetToolsMenuStateCommand(cfg, sess, toolDefs)`
- [x] 2.3 Pass `toolDefs` to `MainController` constructor: add `toolDefs` as 7th parameter

## 3. Command — Update GetToolsMenuStateCommand

- [x] 3.1 Add `toolDefinitions` field and constructor parameter to `commands/GetToolsMenuStateCommand.ahk`
- [x] 3.2 Replace hardcoded `Execute()` body with loop over `this.toolDefinitions`, building `[{label, checked}]` array using `this.configManager.IsToolEnabled()`
- [x] 3.3 Remove direct references to tool class constants (`PowerShellTool.TOOL_NAME`, etc.) — command no longer includes tool classes

## 4. Controller — Update MainController

- [x] 4.1 Add `toolDefinitions` field to `controllers/MainController.ahk`
- [x] 4.2 Accept `toolDefs` as 7th constructor parameter and store it
- [x] 4.3 Add `ToolDefinitions` property getter (same pattern as `ModelDisplayNames` and `SessionLabels`)

## 5. View — Decouple MenuView

- [x] 5.1 Remove `static ToolMapping` array from `ui/MenuView.ahk`
- [x] 5.2 Add `toolDefs` parameter to `Create()` method signature, store as `this.toolDefs`
- [x] 5.3 Replace `for toolInfo in MenuView.ToolMapping` in `Create()` with `for def in toolDefs`, binding `ToggleTool` with `def.id`
- [x] 5.4 Replace `for toolInfo in MenuView.ToolMapping` in `UpdateToolsMenu()` with `for item in toolStates`, using `item.label` and `item.checked`
- [x] 5.5 Remove any implicit `#Include` of tool class files (verify MenuView.ahk does not reference tool class names)

## 6. View — Update MainView

- [x] 6.1 Pass `this.controller.ToolDefinitions` as additional argument to `menuView.Create()` in `BuildUI()` method of `ui/MainView.ahk`

## 7. Integration — Verify end-to-end

- [x] 7.1 Run `main.ahk` and verify Tools menu renders with all 6 items in correct order
- [x] 7.2 Toggle a tool on/off via the menu and verify checkbox updates correctly
- [x] 7.3 Verify tool toggling affects LLM behavior (tool enabled → available in requests; disabled → excluded)
- [x] 7.4 Switch models and verify tool states update per-model
- [x] 7.5 Verify `Reload Settings` rebuilds the tools menu correctly
- [x] 7.6 Update `ARCHITECTURE_REVIEW.md` to mark issue #6 as DONE
