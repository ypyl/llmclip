# LLMClip

LLMClip is an AutoHotkey script that records clipboard content and provides a tray menu for controlling the recording process. It can handle plain text, file paths, and folder paths, and allows you to view and delete recorded clipboard items.

## Features

- Start and stop clipboard recording
- Show a list of copied text and paths
- Delete individual items from the recorded list
- Automatically detects and processes clipboard content from Visual Studio Code

## Installation

1. Download and install [AutoHotkey v2](https://www.autohotkey.com/download/).
2. Save the `clip.ahk` script to your desired location.
3. Run the script by double-clicking the `clip.ahk` file.

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
