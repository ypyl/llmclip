# TODO — Ponytail Audit Findings

From ponytail-audit, ~−130 lines, 1 file deletable, 2 dup blocks collapsed.

## Do

1. **Dedup tool-definition switch** — `OpenAIProvider` / `OllamaProvider` each have a 12-line `if t = PowerShellTool.TOOL_NAME … GetOpenAiToolDefinition()` chain. Replace with loop over `toolsMap` → `tool.GetOpenAiToolDefinition()`.
2. **Collapse StateHelper** — `SaveState`/`LoadState` and `SaveConversation`/`LoadConversation` are identical pairs differing only by file path. One `Save(path, obj)` / `Load(path)` pair covers both. [utils/StateHelper.ahk]
3. **Dead cleanup in LLMClient** — 3 commented-out cleanup blocks + orphaned `selectedLLMType` in finally. Delete. [services/LLM/LLMClient.ahk]
4. **Dead GroqAudioProvider.ParseResponse** — unreachable on success, only `throw` path matters. Strip to `throw`. [services/LLM/Providers/GroqAudioProvider.ahk]

## Maybe (architecture-constrained)

5. **Thin one-line command wrappers** — `StartRecordingCommand`, `StopRecordingCommand`, `ToggleRecordingCommand`, `SelectModelCommand`, `SetProcessingStateCommand`, `ResetAllCommand`, `ClearContextCommand`, `ReloadSettingsCommand`, `RenderMarkdownCommand`, `SetContextItemCheckedCommand`, `UncheckContextCommand`. Each is a single delegation call. AGENTS.md mandates command layer — delete only if you relax the rule. [Commands/]
6. **GetHistoryInfoCommand** — pure getter, controllers can read services per architecture. Cut if rule allows. [Commands/GetHistoryInfoCommand.ahk]

## Nice-to-have

7. **ArrayHelper.SortDescending** — 16-line hand-rolled insertion sort used in 2 places. Inline clone+sort where called. [utils/ArrayHelper.ahk]
8. **TempFileManager** — 30 lines for a static dir constant + clean + join. Inline at the 2 call sites. [utils/TempFileManager.ahk]
9. **LLMClient.GetProvider** — provider-name routing hardcoded alongside providers.json. Routing string list belongs in providers.json. [services/LLM/LLMClient.ahk]
