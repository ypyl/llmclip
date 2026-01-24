# LLMClip

An AutoHotkey v2 clipboard manager that transforms your clipboard history into context for LLM conversations.

![image](./screen.png)

## Overview

LLMClip monitors your clipboard and aggregates copied text, files, and folders into a unified context for AI chat. It seamlessly integrates with various LLM providers (Groq, Ollama, Google Gemini, OpenAI) to allow you to chat with your clipboard content.

## Features

### 📋 Clipboard Monitoring & Context Management
- **Smart Capture**: Automatically captures copied text, file paths, and folder contents.
- **Context Awareness**:
    - **Files & Folders**: Reads content of text-based files and lists folder contents.
    - **PDF Support**: Auto-extracts text and images from PDF files (requires `pdftotext` and `pdfimages`).
    - **Images**: Supports clipboard images and image files for multimodal LLMs.
    - **URLs**: Extracts content and metadata from web links.
- **Selection Control**: Checkboxes allow you to select specific items from your history to send as context.

### 🤖 LLM Integration
- **Multi-Provider**: Pre-configured support for **Groq**, **Ollama**, **Google (Gemini)**, and **OpenAI**.
- **Customizable**: Easy `settings.json` configuration for models, system prompts, and API keys.
- **Tools**: Capable of executing **PowerShell** commands for file system operations when enabled.

### 💬 Advanced Chat Interface
- **Markdown Rendering**: chat history is rendered with Markdown, including syntax highlighting for code blocks.
- **History Management**:
    - **Compression**: "Compress" feature to summarize long conversations and save tokens.
    - **Extract Notes**: "Extract Learnings" to summarize key information from a session.
    - **Editing**: Edit previous user messages and regenerate responses.
- **Session Management**: Switch between multiple independent chat sessions.

## Installation

1.  **Install AutoHotkey v2**: Download from [autohotkey.com](https://www.autohotkey.com/).
2.  **Install cURL**: Ensure `curl` is installed (`winget install cURL.cURL` or via [curl.se](https://curl.se/)).
3.  **PDF Tools (Optional)**: For PDF support, place `pdftotext.exe` and `pdfimages.exe` in a `pdf/` folder within the project directory. (These are part of Xpdf or Poppler utils).
4.  **Clone Repository**: Clone or download this project.
5.  **Configuration**: 
    - Create a `Settings/keys.ini` file for your API keys.
    - (Optional) Customize `providers.json`, `roles.json`, and `system_prompts.json` in the root directory.
6.  **Run**: Execute `clip.ahk`.

## Configuration

### API Keys (`Settings/keys.ini`)

Create a file named `keys.ini` inside the `Settings` folder. Use the following format:

```ini
[Keys]
groq=gsk_your_groq_api_key_here
openai=sk-your-openai-api-key-here
google=your-google-gemini-api-key-here
```

The key name (e.g., `groq`) should match the provider name defined in your configuration.

### Advanced Configuration

- **`providers.json`**: Define LLM endpoints, models, and curl commands.
- **`system_prompts.json`**: Store your reusable system prompts.
- **`roles.json`**: Map providers to specific system prompts and models.

## Usage

### Hotkeys
- **F3**: Toggle Recording / Show Window / Stop Recording cycle.
- **Enter**: Send message.
- **Shift+Enter**: Insert newline.

### Interface Tips
- **Context List**: Uncheck items you don't want to send to the LLM.
- **Images**: If an image is in the clipboard or selected context, it will be sent to multimodal models (like Gemini or GPT-4o).
- **Tools**: Enable the `ps1` checkbox to allow the LLM to write and execute PowerShell scripts (Use with caution!).

## License

MIT License

## Credits

Uses libraries from [thqby/ahk2_lib](https://github.com/thqby/ahk2_lib)