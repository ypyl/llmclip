# LLMClip — Agent Guide

## Language & Runtime

- **AutoHotkey v2** (not v1). Syntax differs significantly: fat-arrow functions, class syntax, `=>` lambdas, no `%` command syntax.
- Entry point: `main.ahk` → instantiates `App()` (in `App.ahk`) → calls `App.Start()`.
- No build step for development. Run `main.ahk` directly with AutoHotkey v2.
- No test suite, no linter, no formatter configured for AHK.

## Architecture (mandatory — see ARCHITECTURE.md)

Violations of these rules are instant bugs:

- **`App.ahk`** is the only composition root. All Services, Commands, Controllers, and Views are instantiated there. No `new`/instantiation outside `App.ahk` (utility static methods exempt).
- **Views** (`ui/`) → structure only, zero logic or state.
- **Controllers** (`controllers/`) → UI coordination only. Can *read* services, never *mutate* them. Controller-to-controller calls are forbidden.
- **Commands** (`commands/`) → the **only** layer allowed to mutate service state. No GUI access. Cannot call other commands.
- **Services** (`services/`) → own domain state, pure logic, OS/persistence. No UI/controller/command references.
- **Utils** (`utils/`) → static helper methods only, no state, no instantiation in App.ahk.

Circular dependency = broken. If View needs Controller and Controller needs View, use property assignment after construction (see `App.ahk` pattern).

## Include System

AHK uses `#Include` for dependency resolution. All includes are listed at the top of `App.ahk` — this doubles as the dependency registry. When adding a new class file, you must add the `#Include` in `App.ahk`.

Include paths in sub-files are relative to that file (e.g., `#Include ..\Services\ProcessingState.ahk` from a Command).

## Key Files & Directories

| Path | Role |
|---|---|
| `main.ahk` | Bootstrap — creates App and starts it |
| `App.ahk` | Composition root — all DI and wiring |
| `commands/` | One class per use-case, each with `Execute()` method |
| `controllers/` | 6 controllers mapping UI events to commands |
| `services/` | State owners: `ConfigurationService` (singleton via `GetInstance()`), `SessionManager`, `ContextManager`, `LLMService`, `RecordingService`, `WebViewManager` |
| `services/LLM/` | LLM client, providers (OpenAI-compatible, Google, Ollama, Groq), and tool implementations |
| `services/Configuration/` | `ConfigurationService`, `Providers`, `SystemPrompts`, `Roles` |
| `ui/` | WebView2-based GUI; `UIConfig` holds layout constants |
| `utils/` | Pure static helpers (Clipboard, File, Base64, etc.) |
| `Lib/` | **Vendored** dependencies from [thqby/ahk2_lib](https://github.com/thqby/ahk2_lib) — do not modify |
| `providers/providers.json` | LLM endpoint definitions (curl templates, model lists, tool flags) — runtime config |
| `keys.ini` | API keys — gitignored, must be created locally |
| `roles.json` | Model-to-prompt-role mapping — runtime config |
| `prompts/` | System prompt JSON files — gitignored, user-customizable |

## Configuration & Runtime

- `ConfigurationService` is a **singleton** — always access via `ConfigurationService.GetInstance()`.
- `providers/providers.json` and `prompts/` directory JSONs are merged at runtime (multiple JSON files combine).
- `keys.ini` section names must match provider names in `providers.json` (e.g., `[Groq]`, `[Google]`).
- LLM calls use **curl** subprocess — cURL must be installed and on PATH.
- Tool auto-approval is configured in system prompt JSONs via `tools.{ToolName}.{parameterName}` regex patterns (see `TOOL_AUTO_APPROVAL.md`).

## Release

- CI (`.github/workflows/release.yml`): triggered on semver tag push (`v*.*.*`). Compiles `main.ahk` → `llmclip.exe` with `icon.ico`.
- Release zip bundles: `llmclip.exe`, `mermaid.min.js`, `providers/providers.json`, `ui.html`, `marked.min.js`, `readability.min.js`, `WebView2Loader.dll`.
- Uses `benmusson/ahk2exe-action@v1.2.0` for compilation.

## Common Pitfalls

- **AHK v2 only** — v1 syntax breaks silently or with confusing errors.
- **No controller-to-controller calls** — route through MainController or restructure.
- **Commands cannot access UI** — if a command needs UI feedback, the controller calls the command then updates the view.
- **`Lib/` files are vendored** — don't edit them; update from upstream if needed.
- **`providers/` and `prompts/` are runtime configs**, not code — JSON format, combined at startup.