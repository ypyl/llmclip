# Code Audit — Bugs, Issues & Refactoring Opportunities

> Generated from deep codebase exploration — May 2026
> Covers all `.ahk` files across Commands, Controllers, Services, Utils, and UI

---

## 🔴 Critical Bugs (Will Crash or Produce Wrong Results)

### B1. `SendBatchToLLMCommand` — Missing method on `tempSession` ✅ **FIXED**

> **Fix**: `openspec/changes/fix-batch-mode-stub-crash` — eliminated the stub entirely. `LLMService.SendToLLM()` now accepts `(messages, modelIndex, ...)` directly rather than requiring a `SessionManager`-shaped object.

**File**: `Commands\SendBatchToLLMCommand.ahk` (line ~53)  
**Impact**: ~~Batch mode is completely broken — crashes when sending batch items to LLM.~~

The stub object `tempSession` exposes `GetSessionLLMType`, but `LLMService.SendToLLM` calls `GetSessionModelIndex`. Method name mismatch:

```ahk
; SendBatchToLLMCommand builds:
tempSession := {
    GetSessionLLMType: (*) => ...    ; ← wrong name
    ...
}

; LLMService.SendToLLM calls:
settings := this.configManager.GetSelectedSettings(
    sessionManager.GetSessionModelIndex(sessionIndex)  ; ← needs THIS
)
```

**Fix**: Rename `GetSessionLLMType` → `GetSessionModelIndex` in the stub object, or add both methods.

---

### ~~B2. `ClipboardParserService.Parse()` — Variable shadowing~~ ❌ FALSE POSITIVE

**File**: `Utils\ClipboardParserService.ahk`  
**Impact**: ~~Path splitting silently fails due to block-scoped variable shadowing.~~ **This is not a bug.** AHK v2 has function-level scoping, not block-level scoping. `if`/`for`/`while` bodies do NOT create new variable scopes. Every `:=` after the initial declaration is a reassignment to the same function-scoped variable. The code works correctly.

However, the function has other issues:

#### MsgBox in a Utils class (architectural violation)

```ahk
} catch as e {
    MsgBox "Error processing clipboard: " e.Message   ; ← GUI from Utils!
}
```

Utils are forbidden from GUI access. The catch block pops a dialog without context.

**Fix**: Throw the exception or return a distinguishable error. Let the caller (controller/command) decide how to surface it.

#### Silent data loss on partial failure

If `ClipboardAll()` fails mid-way inside the VS Code block, `localTxtFromClipboardArray` may be partially populated. The function continues, hits the image fallback, and may return `[]` — silently discarding clipboard content with no error propagation.

**Fix**: Bubble errors up rather than swallowing them. Return a sentinel or throw so the caller can react.

#### Internal quotes not handled when splitting paths

```ahk
txtFromClipboard := Trim(A_Clipboard, '"')
```

If Explorer copies paths with spaces (e.g., `"C:\File A.txt"`), individual paths retain their quotes after Trim, causing `FileExist()` to fail. Low-priority edge case.

---

### ~~B3. `MainController.AskToLLM` — Auto-approval loop variable scoping~~ ❌ FALSE POSITIVE

**File**: `Controllers\MainController.ahk` (lines ~265-282)  
**Impact**: ~~Auto-approved tool calls may loop infinitely because the loop condition reads a stale `result`.~~ **This is not a bug.** AHK v2 has function-level scoping — `while` bodies do NOT create new variable scopes. The `result :=` inside the loop body is a reassignment of the same function-scoped variable. The `while` condition re-evaluates `result.action` on each iteration. The auto-approval loop works correctly.

---

## 🟠 Semantic Issues (Works But Wrong)

### S1. `CompressHistoryCommand` — Dead prompt-building code ✅ **FIXED**

> **Fix**: `openspec/changes/archive/2026-05-27-decouple-compression-from-session` — eliminated duplicate validation and prompt-building. `LLMService.CompressHistory()` now accepts `(messages, conversationText, modelIndex)` directly; the command extracts data and passes it, service owns all validation and prompt logic.

**File**: `Commands\CompressHistoryCommand.ahk` (lines ~30-42)  
**Impact**: ~~Wasted computation; potential for config drift if prompt-building logic diverges.~~

The command built a `compressionPrompt` string but never used it — the service rebuilt it from scratch.

**Fix**: Service now accepts pre-extracted data. Command extracts messages, conversationText, modelIndex and passes them directly. No duplication.

---

### S2. `ExtractLearningsCommand` — Same duplicate validation as S1 ✅ **FIXED**

> **Fix**: Same change as S1. `LLMService.ExtractLearnings()` now accepts `(messages, conversationText, modelIndex)` directly. Command extracts data and passes it.

**File**: `Commands\ExtractLearningsCommand.ahk` (lines ~14-22)  
**Impact**: ~~Same pattern as S1 — duplicate validation. Both the command and the service check `messages.Length < 2` and build conversation text independently.~~

**Fix**: Command now extracts messages, conversationText, modelIndex and passes them to the service. Service owns all validation. No duplication.

---

### ~~S3. `SaveStateOnExitCommand` — Saves `batchMode` globally but it's session-scoped~~ ✅ BY DESIGN

**File**: `Commands\SaveStateOnExitCommand.ahk`  
**Impact**: ~~Batch mode state is written as a top-level flag but conceptually belongs to the current session.~~ **This is not a bug.** `batchModeEnabled` lives on `SessionManager` (not `Session`) — it is a global app preference, consistently with `answerSize`. Both are saved/loaded identically. Switching sessions does not change batch mode state, confirming it's intentionally global.

---

### S4. `ConfigurationService.SetToolEnabled` — Ephemeral writes ✅ **FIXED**

> **Fix**: `openspec/changes/persist-tool-preferences` — user tool preferences are now stored in a per-model `toolOverrides` Map, persisted to `state.json`, and survive `Reload()` and app restarts. `IsToolEnabled()` reads overrides before falling back to provider defaults. `SetToolEnabled()` writes to overrides instead of mutating the providers cache.

**File**: `Services\Configuration\ConfigurationService.ahk` (line ~130)  
**Impact**: ~~Toggling tools in the UI appears to work but changes are lost on the next read because `GetSelectedSettings()` rebuilds the settings object from providers on every call.~~

```ahk
SetToolEnabled(modelIndex, toolName, enabled) {
    settings := this.GetSelectedSettings(modelIndex)  ; fresh object from providers
    settings["tools"] := newTools                     ; mutates temporary copy
    ; never persisted — changes evaporate
}
```

**Fix**: Store tool enablement state in a separate persistent structure (e.g., `state.json` or a dedicated config file) and merge it with provider defaults at read time.

---

### S5. `DeleteMessageCommand` — Relies on caller-sorted indices

**File**: `Commands\DeleteMessageCommand.ahk`  
**Impact**: If called with non-descending indices, array shifts during deletion produce wrong results. Currently works because `HistoryViewController._SortDescending()` pre-sorts, but the command itself has no guard.

**Fix**: Sort indices descending inside the command, or at minimum add an assertion/comment documenting the pre-condition.

---

## 🟡 Architecture & Design Issues

### A1. `MainView` is a God Object Proxy

**File**: `ui\MainView.ahk`  
**Impact**: Maintenance burden, coupling, and unnecessary indirection.

```
MainView
├── modelMenu          → delegates to MenuView
├── contextBox         → delegates to ContextView  
├── AddContextBoxItem() → delegates
├── DeleteChatHistoryItems() → delegates
├── SetAskButtonText() → delegates to PromptView
├── ...20+ proxy methods...
```

Every sub-view operation tunnels through `MainView`. Controllers should hold direct references to the specific sub-views they coordinate.

**Refactoring**: Pass sub-view references directly to controllers/sub-controllers instead of forcing everything through `MainView`.

---

### A2. Duplicated validation between Commands and Services

**Pattern**: `CompressHistoryCommand` and `LLMService.CompressHistory` both validate message count, format conversation text, and build prompts. Same for `ExtractLearningsCommand` / `LLMService.ExtractLearnings`.

```
┌─────────────────────┐     ┌──────────────────────┐
│ Command             │     │ Service              │
│ Check msg.Length ✓  │     │ Check msg.Length ✓   │ ← duplicate
│ Format messages  ✓  │     │ Format messages  ✓   │ ← duplicate  
│ Build prompt     ✓  │     │ Build prompt     ✓   │ ← duplicate
│ ──call service──────┼────▶│ Call LLM             │
└─────────────────────┘     └──────────────────────┘
```

**Fix**: Commands should be thin pass-throughs. Move all validation and prompt construction into the service.

---

### A3. `Roles` class — Dead code behind a feature flag

**File**: `Services\Configuration\Roles.ahk`  
**Impact**: Dead code, confusion for new contributors.

```ahk
class Roles {
    ROLES_DISABLED := true       ; permanently disabled
    GetPromptsForProvider(...) {
        if (!this.ROLES_DISABLED) {
            ; unreachable code
        }
        return []                 ; always empty → caller falls back to all prompts
    }
}
```

**Fix**: Remove the `Roles` class entirely, or remove the flag and always return all prompts. The `roles.json` file parsing can stay for future re-enablement.

---

### A4. Magic strings scattered across codebase

| Hardcoded String | Locations |
|-----------------|-----------|
| `"prompts"` | `SystemPrompts`, `PromptCreatorTool`, `ConfigurationService` |
| `"state.json"` | `StateService` (centralized ✓) |
| `"conversation.json"` | `StateService` (centralized ✓) |
| `"providers"` | `Providers`, app-level |
| `"keys.ini"` | `ConfigurationService` |
| `MAX_SESSIONS := 5` | `SessionManager`, `MainController.SessionLabels` |
| `"temp"` | `TempFileManager` (centralized ✓) |

**Fix**: Consolidate directory paths into a `Paths` or `AppConfig` constant class.

---

### A5. `InitializeAppCommand` is trivially thin

**File**: `Commands\InitializeAppCommand.ahk` (8 lines)  
**Impact**: Adds a file and App.ahk wiring for a single `TempFileManager.CleanUp()` call.

**Fix**: Inline into `MainController.Start()`, removing the command file.

---

## 🟢 Minor Code Quality

### M1. Duplicate comment in `OllamaProvider.ParseResponse`

**File**: `Services\LLM\Providers\OllamaProvider.ahk` (line ~88)  
`"; Handle format with direct message object (Ollama often returns this)"` appears twice on consecutive lines.

---

### M2. `WebViewManager.EscapeForJs` — Fragile HTML escaping

**File**: `Services\WebViewManager.ahk`  
Skips escaping `<` and `>` only when content starts with `<audio`. This is an inconsistent heuristic:
```ahk
if (InStr(escapedMd, "<audio") != 1) {
    escapedMd := StrReplace(escapedMd, "<", "&lt;")
    escapedMd := StrReplace(escapedMd, ">", "&gt;")
}
```

**Fix**: Either always escape (let the renderer handle it), or use a proper sanitization approach.

---

### M3. No consistent error protocol

Some commands throw exceptions, some return `false`, some return `""`. No standard pattern exists:

| Pattern | Example |
|---------|---------|
| Throws | `CompressHistoryCommand.Run()` throws on short history |
| Returns false | `ProcessClipboardCommand.Execute()` returns false if not recording |
| Returns "" | `RegenerateMessageCommand.Execute()` returns "" on invalid index |
| Returns object | `SendToLLMCommand.Execute()` returns `{action: ...}` |

**Fix**: Adopt a `{success, error?, data?}` result pattern, or consistently throw with try/catch at controller level.

---

### M4. `ProcessClipboardCommand` — No error boundary

**File**: `Commands\ProcessClipboardCommand.ahk`  
If `ClipboardParserService.Parse()` throws (e.g., clipboard access denied), the clipboard change handler in `MainController.ClipChanged` silently breaks and clipboard monitoring stops working.

**Fix**: Wrap in try/catch.

---

### M5. `MainController.Start()` — Missing error handling for state loading

**File**: `Controllers\MainController.ahk` (line ~85)  
```ahk
try {
    this.loadStateOnStartCommand.Execute()
    this.loadConversationOnStartCommand.Execute()
}
```
The `try` block has no `catch` — if either command throws, the error is silently swallowed.

---

### M6. `RecordingController.OnToggleRecording` — Duplicate logic

**File**: `Controllers\RecordingController.ahk`  
The controller checks `recordingService.isRecording` and decides which command to call, but `ToggleRecordingCommand` already contains that logic. The controller re-implements the toggle decision.

---

## 📊 Summary

| Severity | Count | Items |
|----------|-------|-------|
| 🔴 Critical Bug | 1 | B1 (fixed) |
| 🟠 Semantic Issue | 5 | S1 (fixed), S2 (fixed), S3 (by design), S4 (fixed), S5 |
| 🟡 Architecture | 5 | A1–A5 |
| 🟢 Minor | 6 | M1–M6 |
| ❌ False Positive | 2 | B2, B3 (corrected — see inline) |
| **Total (real)** | **17** | |

---

## Recommended Priority Order

1. **B1** — Batch mode crash (affects all batch users)
2. **B2** — Clipboard path splitting broken (core feature)
3. **B3** — Auto-approval infinite loop (edge case but critical)
4. **S3** — State save/load correctness
5. **S4** — Tool toggle persistence
6. **S1/S2/A2** — Duplicate validation cleanup
7. **A1** — MainView proxy refactoring (nice to have)
8. Everything else
