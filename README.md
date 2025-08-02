# LLMClip: Your Clipboard-Powered AI Assistant

LLMClip is an AutoHotkey v2 script that supercharges your workflow by using clipboard content as context for Large Language Models (LLMs). It records text, files, and folder paths you copy, and lets you use that information in a powerful, feature-rich chat interface.

![image](https://github.com/user-attachments/assets/795a1050-e56e-4cae-890c-52286d953979)

## Primary Goal

The core mission of LLMClip is to seamlessly aggregate everything you copy—text snippets, file paths, folder contents—into a unified context that can be passed to an LLM. This turns your clipboard history into a dynamic knowledge base for your AI assistant.

## Features

### Intelligent Clipboard & Context Management
- **Clipboard Recording**: Start and stop clipboard monitoring with a global hotkey or from the tray menu.
- **Smart Parsing**: Automatically captures and understands plain text, file paths, and folder paths. It intelligently extracts content from files and avoids adding duplicate information.
- **Unified Context List**: All captured items are displayed in a clean list. Click an item to preview its content, or `Ctrl+Click` to select multiple items, focusing the LLM on the most relevant information for your query.
- **Full Control**: Easily manage your context by deleting selected items, clearing the entire list, or resetting your selection.

### Powerful LLM Interaction
- **Rich Chat Interface**: A dual-panel UI with your controls on the left and the conversation on the right.
- **Multi-Provider Support**: Natively supports Groq, Google, and Ollama. Easily configurable in `settings.json` to add your own providers.
- **Dynamic Controls**: Switch between LLMs, system prompts, and even control the desired length of the AI's answer (short, medium, or long) directly from the UI.
- **Session Management**: Organizes your chats into distinct sessions. Start a new chat or switch back to a previous one at any time.

### Advanced Capabilities
- **Tool Integration**: Empowers the LLM to interact with your system by executing shell commands (`ComSpec`) and performing file system operations like reading, writing, and deleting files.
- **Interactive Responses**: LLM responses are rendered in Markdown. You can copy the full message or just a specific code block with a single click.
- **One-Click Tool Execution**: If the LLM suggests a tool call (e.g., to read a file or run a command), a "Run Tool" button appears, allowing you to execute it safely and instantly.

## Installation

1.  Download and install **AutoHotkey v2** from the [official website](https://www.autohotkey.com/download/).
2.  Install **cURL** for making API requests. You can use either method:
    *   In PowerShell, run: `winget install cURL.cURL`
    *   Download directly from [curl.se](https://curl.se/download.html).
3.  Save the `clip.ahk` script and its accompanying files to a folder on your computer.
4.  In the same folder, create a `settings.json` file (an example is provided below).
5.  Run the script by double-clicking the `clip.ahk` file.

## Usage

### Hotkeys

| Key | Action | Description |
| :--- | :--- | :--- |
| **F3** | Smart Toggle | Cycles through **Start Recording** -> **Show UI** -> **Stop Recording**. |
| **F12** | Show UI | Brings the chat window to the foreground if it's hidden. |
| **Enter** | Send Message | In the prompt input, sends your message to the LLM. |
| **Shift+Enter** | New Line | In the prompt input, adds a new line instead of sending. |

### Tray Menu
- **Left-click** the tray icon to quickly toggle clipboard recording on or off.
- **Right-click** the tray icon for a full menu:
    - **Start/Stop Recording**: Manually control the clipboard listener.
    - **Ask LLM**: Open the main chat interface.
    - **Exit**: Close the application.

### The Chat Interface
The main window is split into two panels:

- **Left Panel (Your Controls):**
    - **Session Dropdown**: Switch between different chat sessions.
    - **Context List**: Your clipboard history. This is your knowledge base.
    - **Chat History**: The log of your current conversation. Click a message to view its full content or to access the "Run Tool" / "Copy" button again.
    - **Prompt Area**: Type your questions here. Above the LLM selector, you can find:
        - **Tool Checkboxes**: Enable or disable `ComSpec` (command line) and `FileSystem` tools for the next query.
        - **Answer Size Dropdown**: Hint to the LLM how long you want the response to be.

- **Right Panel (The Conversation):**
    - This area displays the full content of any item you select—a context item, a chat history message, or the latest LLM response, all beautifully rendered.

## LLM Configuration

The `settings.json` file is where you configure the LLM providers. You must provide your own API keys.

**Example `settings.json`:**
```json
{
    "selectedLLMType": "groq",
    "providers": {
        "groq": {
            "curl": "curl -s -S -X POST "https://api.groq.com/openai/v1/chat/completions" -H "Content-Type: application/json" -H "Authorization: Bearer <<KEY>>" -d "@{1}" -o "{2}"",
            "model": "llama-3.3-70b-versatile",
            "temperature": 0.7,
            "system_prompt": "You are a helpful assistant. Be concise and direct in your responses."
        },
        "google": {
            "curl": "curl -s -S -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=<<KEY>>" -H "Content-Type: application/json" -d "@{1}" -o "{2}"",
            "model": "gemini-1.5-flash",
            "temperature": 0.7,
            "system_prompt": "You are a helpful assistant. Be concise and direct in your responses."
        },
        "ollama": {
            "curl": "curl -s -S -X POST "http://localhost:11434/api/chat" -H "Content-Type: application/json" -d "@{1}" -o "{2}"",
            "model": "llama3",
            "temperature": 0.7,
            "system_prompt": "You are a helpful assistant. Be concise and direct in your responses."
        },
        "github": {
            "curl": "curl -s -S -X POST "https://models.github.ai/inference/chat/completions" -H "Content-Type: application/json" -H "Authorization: Bearer <<YOUR_GITHUB_TOKEN>>" -d "@{1}" -o "{2}"",
            "model": "openai/gpt-4o-mini",
            "temperature": 0.7,
            "system_prompt": "You are a GitHub Copilot assistant. Your goal is to help with code."
        }
    }
}
```
**Important**: Replace `<<KEY>>` with your actual API key for each service.

## Contributing

Feel free to submit issues or pull requests if you have suggestions or improvements.

## License

This project is licensed under the MIT License.
