# LLMClip

LLMClip is an AutoHotkey script that records clipboard content and provides a tray menu for controlling the recording process. It can handle plain text, file paths, and folder paths, and allows you to view and delete recorded clipboard items.

## Features

- Start and stop clipboard recording
- Show a list of copied text and paths
- Delete individual items from the recorded list
- Automatically detects and processes clipboard content from Visual Studio Code

## Primary Goal

The primary goal of LLMClip is to combine all copied data from the clipboard (including text, file paths, folder paths, and their content) into one text value that can be passed to a Large Language Model (LLM) as context.

## Installation

1. Download and install [AutoHotkey v2](https://www.autohotkey.com/download/).
2. Install cURL using one of these methods:
   - Run `winget install cURL.cURL` in PowerShell
   - Download from [curl.se](https://curl.se/download.html)
3. Save the `clip.ahk` script to your desired location.
4. Create a `settings.ahk` file in the same directory with your LLM configurations.
5. Run the script by double-clicking the `clip.ahk` file.

## LLM Configuration

The `settings.ahk` file contains configurations for different LLM providers. The example script includes built-in support for:

- Groq (using llama-3.3-70b-versatile model)
- Google (using gemini-2.0-flash model)

Example `settings.ahk`:
```autohotkey
GetLLMSettings() {
    return Map(
        "groq", Map(
            "curl", 'curl -s -S -X POST "https://api.groq.com/openai/v1/chat/completions" -H "Content-Type: application/json" -H "Authorization: Bearer <<KEY>" -d "@{1}" -o "{2}"',
            "model", "llama-3.3-70b-versatile",
            "temperature", 0.7,
            "system_prompt", "You are a helpful assistant. Be concise and direct in your responses.",
        ),
        "google", Map(
            "curl", 'curl -s -S -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=<<KEY>>" -H "Content-Type: application/json" -d "@{1}" -o "{2}"',
            "system_prompt", "You are a helpful assistant. Be concise and direct in your responses.",
            "temperature", 0.7,
        ))
}
```

Replace `<<KEY>` with your actual API keys for each service.

## Usage

### Tray Menu

- **Start Recording**: Starts recording clipboard content.
- **Stop Recording**: Stops recording clipboard content and copies the recorded text to the clipboard.
- **Show Copied Text**: Displays a list of recorded clipboard items, allowing you to delete individual items.
- **Exit**: Exits the script.

### Hotkeys

- **Ctrl + Alt + R**: Toggles recording on and off.

### Clipboard Content Handling

- The script records plain text, file paths, and folder paths.
- When recording is stopped, the recorded content is copied to the clipboard.
- If the clipboard content is from Visual Studio Code, the script attempts to extract file URIs.

## Contributing

Feel free to submit issues or pull requests if you have suggestions or improvements.

## License

This project is licensed under the MIT License.
