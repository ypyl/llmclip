# LLMClip

LLMClip is an AutoHotkey script that records clipboard content and provides a tray menu for controlling the recording process. It can handle plain text, file paths, and folder paths, and allows you to interact with LLMs using the collected content.

![image](https://github.com/user-attachments/assets/795a1050-e56e-4cae-890c-52286d953979)

## Features

- Start and stop clipboard recording
- Show a list of copied text and paths
- Delete individual items from the recorded list
- Automatically detects and processes clipboard content from Visual Studio Code
- Smart clipboard content parsing for different data types
- Interactive GUI for managing context and chatting with LLMs
- Support for multiple LLM providers (Groq, Google, Ollama)
- Multi-select context items for focused LLM queries
- Chat history tracking and management
- Built-in tools for file operations and command execution
- Support for function calling in compatible LLMs
- Markdown rendering for responses with code block management
- Collapsible and copyable code blocks in responses

## Primary Goal

The primary goal of LLMClip is to combine all copied data from the clipboard (including text, file paths, folder paths, and their content) into one text value that can be passed to a Large Language Model (LLM) as context.

## Installation

1. Download and install [AutoHotkey v2](https://www.autohotkey.com/download/).
2. Install cURL using one of these methods:
   - Run `winget install cURL.cURL` in PowerShell
   - Download from [curl.se](https://curl.se/download.html)
3. Save the `clip.ahk` script to your desired location.
4. Create a `settings.json` file in the same directory with your LLM configurations.
5. Run the script by double-clicking the `clip.ahk` file.

## Usage

### Hotkeys

- **F3**: Smart toggle key
  - First press: Start recording
  - Second press: Open LLM chat interface
  - Third press: Stop recording
- **Left-click** on tray icon: Toggle recording on/off

### Tray Menu

- **Start Recording**: Starts recording clipboard content
- **Stop Recording**: Stops recording clipboard content
- **Ask LLM**: Opens the LLM chat interface
- **Exit**: Exits the script

### LLM Chat Interface

The chat interface provides several features:
- LLM provider selection dropdown
- Context list with multi-select support
- Chat history view
- Response viewer
- Interactive prompt input
- Tool execution support for compatible models

### Context Management

- Select multiple context items to focus the LLM's attention
- Clear all context or selected items
- View raw content of selected context items
- Delete individual context items

### Tools Support

LLMClip includes built-in tools that compatible LLM providers can use:

#### File System Tool
- Read file contents
- Write content to files
- Delete files
- Full path support for file operations
- Automatic error handling and reporting

#### Command Line Tool
- Execute commands in Windows Command Prompt
- Capture command output
- Support for complex command arguments
- Error handling and status reporting

When an LLM suggests using a tool, a "Run Tool" button will appear to execute the suggested operation.

### Chat Features

- Chat history tracking
- Clear chat history
- View full message content by selecting chat history items
- Press Enter to send message (Shift+Enter for new line)
- Execute suggested tools with one click

## LLM Configuration

The `settings.json` file contains configurations for different LLM providers. The example script includes built-in support for:

- Groq (using llama-3.3-70b-versatile model)
- Google (using gemini-2.0-flash model)
- Ollama (local models support)

Each provider can be configured with:
- Custom temperature settings
- Model selection
- System prompts
- API endpoints and authentication

Example `settings.json`:
```json
{
    "selectedLLMType": "groq",
    "providers": {
        "groq": {
            "curl": "curl -s -S -X POST \"https://api.groq.com/openai/v1/chat/completions\" -H \"Content-Type: application/json\" -H \"Authorization: Bearer <<KEY>>\" -d \"@{1}\" -o \"{2}\"",
            "model": "llama-3.3-70b-versatile",
            "temperature": 0.7,
            "system_prompt": "You are a helpful assistant. Be concise and direct in your responses."
        }
        // ...other provider configurations...
    }
}
```

Replace `<<KEY>>` with your actual API keys for each service.

## Contributing

Feel free to submit issues or pull requests if you have suggestions or improvements.

## License

This project is licensed under the MIT License.
