# LLMClip

An AutoHotkey v2 clipboard manager that transforms your clipboard history into context for LLM conversations.

![image](./screen.png)

## Overview

LLMClip monitors your clipboard and aggregates copied text, files, folders, images, and URLs into a unified context for AI chat. It integrates with multiple LLM providers — GitHub Models, Groq, Google Gemini, Ollama, OpenRouter, Nvidia, and OpenCodeGo — allowing you to chat with your clipboard content, auto-execute tools, and manage independent multi-session conversations.

## Features

### 📋 Clipboard Monitoring & Context Management
- **Smart Capture**: Automatically captures copied text, file paths, folder contents, and images.
- **Context Awareness**:
    - **Files & Folders**: Reads content of text-based files and recursively lists folder contents.
    - **Images**: Supports clipboard images and image files for multimodal LLMs (Gemini, GPT-4o, Qwen-VL).
    - **URLs**: Extracts content and metadata from web links; double-click a URL to convert it to Markdown via the markdown.new service.
- **Selection Control**: Checkboxes allow you to select specific items from your history to send as context. Selected items are highlighted as `<SELECTED_CONTEXT>` in the prompt, while checked items appear as general `<CONTEXT>`.

### 🤖 LLM Integration
- **9 Built-in Providers**: Pre-configured support for **GitHub Models**, **Groq**, **Groq Audio** (TTS), **Google (Gemini)**, **Ollama Local**, **Ollama Cloud**, **OpenRouter**, **Nvidia**, and **OpenCodeGo**.
- **Customizable**: Flexible configuration via `providers/` and `prompts/` directories — all `*.json` files in each are merged at runtime. Define curl templates, models, tool flags, system prompts with templates, and auto-approval rules.
- **Per-Model System Prompts**: Multiple system prompt roles are selectable from a dropdown for every model. All prompts are available to all providers. System prompts can include input templates with `{placeholders}`.
- **Tools**: Allow models to execute terminal commands, read/write files, search the web, fetch pages, and more. Available tools:
    - `execute_powershell`: Run PowerShell scripts for system operations.
    - `file_system`: Perform local file read, write, and list operations.
    - `web_search`: Perform a web search to get the latest information.
    - `web_fetch`: Read the content of a specific web page by URL.
    - `read_url_markdown`: Cleanly convert web pages to Markdown via markdown.new.
- **Tool Auto-Approval**: Configure regex patterns per system prompt to automatically execute safe tool calls without manual confirmation. Add `"tools.{ToolName}.{parameter}": "regex"` keys to a prompt's JSON — when all patterns match, the tool executes without the approval dialog. Falls back to manual confirmation if any pattern fails. Disable by removing all `tools.*` keys.

### 💬 Advanced Chat Interface
- **Markdown Rendering**: Chat history is rendered with Markdown, including syntax highlighting for code blocks.
    - **Mermaid Diagrams**: Supports rendering of Mermaid diagrams for visual workflows and charts.
    - **Save as SVG**: Save generated diagrams directly from the chat interface.
- **History Management**:
    - **In-place Editing**: Double-click the **markdown view** of any message to edit its content directly (preserves images and tool calls). The editor toolbar shows only Save and Cancel for a focused editing experience.
    - **Branching**: Double-click any previous **user** message to create a new history branch (timeline). Navigate with **⬅/➡** buttons in the chat footer. Buttons auto-disable at edge branches and hide when there is only one branch. Delete button disables when no message is selected.
- **Session Management**: Switch between up to **5 independent chat sessions**, each with its own model, system prompt, chat history, and context items. Session labels show the active system prompt name.
- **Persistence**:
    - **Manual**: Save/Load conversations as JSON via **File → Save/Load Conversation**.
    - **Automatic**: App state and the last conversation are auto-saved on exit and auto-restored on startup.
    - **Session Traceability**: Every LLM API call is logged as a JSONL line in the `sessions/` folder (one file per app launch). Each line captures the triggering message, provider, model, raw response, duration, and token usage — enabling auditing and debugging of all LLM interactions.

## Installation

1. **Install AutoHotkey v2**: Download from [autohotkey.com](https://www.autohotkey.com/).
2. **Install cURL**: Ensure `curl` is installed (`winget install cURL.cURL` or via [curl.se](https://curl.se/)).
3. **Clone Repository**: Clone or download this project.
4. **Configuration**:
    - Create a `keys.ini` file for your API keys (see below).
    - (Optional) Customize files in `providers/` and `prompts/` directories.
5. **Run**: Execute `main.ahk`.

## Configuration

### API Keys (`keys.ini`)

Create a file named `keys.ini` in the root directory. Use the following format:

```ini
[GitHub]
api_key=your_github_token_here

[Groq]
api_key=your_groq_api_key_here

[GroqAudio]
api_key=your_groq_audio_api_key_here

[Google]
api_key=your_google_gemini_api_key_here

[OllamaCloud]
api_key=your_ollama_cloud_api_key_here

[OpenRouter]
api_key=your_openrouter_api_key_here

[Nvidia]
api_key=your_nvidia_api_key_here

[OpenCodeGo]
api_key=your_opencodego_api_key_here
```

Section names must match provider names defined in `providers/providers.json`. Omit sections for providers you don't use.

### Advanced Configuration

- **`providers/`**: Contains provider JSON files (`.json`). All files in this directory are merged at runtime. Each defines LLM endpoints, curl command templates, model lists, image support flags, and tool capabilities. The included `providers.json` serves as the default; if you add additional files, `providers.json` is skipped in favor of your custom files. Add or customize providers by creating files here.
- **`prompts/`**: Contains system prompt JSON files (`.json` only; `.md` files are ignored at runtime). All JSON files in this directory are merged at startup. Each prompt can define:
    - `"value"`: The system prompt text.
    - `"input_template"`: Optional template with `{placeholders}` pre-filled into the input box.
    - `"tools.{ToolName}.{parameter}"`: Regex patterns for auto-approving specific tool calls (e.g., `"tools.FileSystemTool.operation": "read_file|list_dir"` to auto-approve read-only file ops). All defined patterns must match the tool call, otherwise fall back to manual approval.

## Usage

### Hotkeys
- **F6**: Toggle Recording / Show Window / Stop Recording cycle.
- **F5**: Reset All — clear history, context, and reinitialize the current session.
- **F7**: Send to LLM — quick-send the current prompt from any window without focusing the GUI.
- **Enter**: Send message.
- **Shift+Enter**: Insert newline.

### Interface Tips
- **Context List**: Check items to include them as general context; use **Ctrl+Click** to select specific items for focused attention in the prompt.
- **Images**: If an image is in the clipboard or selected context, it will be sent to multimodal models (Gemini, GPT-4o, Qwen-VL, etc.).
- **Tools**: Enable tools per-session via the **Tools** menu. When an LLM requests a tool, the Ask button changes to **Confirm Tool Run** — review and approve or cancel. Configure auto-approval rules in system prompts for trusted operations.
- **System Prompts**: Select from the dropdown above the input box. Changing the prompt updates the current session immediately and may insert an input template.
- **Sessions**: Switch sessions via the session menu (shows prompt names as labels). Each session is fully independent.

## Architecture

This project strictly separates UI, logic, intent, and state domains:
- **`main.ahk`**: Bootstrap — creates `App` and starts it.
- **`App.ahk`**: Composition root — all dependency injection and wiring. The `#Include` list doubles as the dependency registry.
- **`ui/` (Views)**: Passive GUI structure. Creates controls and forwards events. Zero logic and state.
- **`controllers/`**: UI coordination. Receives UI events, reads services, invokes commands. Never mutates service state directly.
- **`commands/`**: Distinct use-cases mutating application state. One class per intent, each with an `Execute()` method. No UI access.
- **`services/`**: Domain state owners and pure UI-agnostic logic. Includes the LLM client, providers, tools, session/context management, and configuration.
- **`utils/`**: Static helper methods only — clipboard, files, base64, formatting. No state, no instantiation in `App.ahk`.

Read the complete architectural guidelines in [ARCHITECTURE.md](./ARCHITECTURE.md).

## License

MIT License

## Credits

Uses libraries from [thqby/ahk2_lib](https://github.com/thqby/ahk2_lib)
