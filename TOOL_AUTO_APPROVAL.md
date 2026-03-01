# Tool Auto-Approval Feature

## Overview

The auto-approval feature allows you to configure regex patterns in your system prompts to automatically execute specific tool calls without requiring manual confirmation. This is useful for safe, read-only operations or trusted workflows.

## Configuration

Add auto-approval patterns to your system prompt JSON files in the `prompts/` directory using the following format:

```json
{
  "YourPromptName": {
    "value": "Your system prompt text here...",
    "tools.{ToolName}.{parameterName}": "regex_pattern"
  }
}
```

### Tool Names

- `PowerShellTool` - For `execute_powershell` tool calls
- `FileSystemTool` - For `file_system` tool calls
- `WebSearchTool` - For `web_search` tool calls
- `WebFetchTool` - For `web_fetch` tool calls
- `MarkdownNewTool` - For `read_url_markdown` tool calls

### Parameter Names

Each tool has specific parameters you can match against:

**PowerShellTool:**
- `script` - The PowerShell script content
- `working_directory` - The working directory path

**FileSystemTool:**
- `operation` - The operation type (read_file, write_file, list_dir)
- `path` - The file or directory path
- `content` - The content to write (for write_file)

**WebSearchTool:**
- `query` - The search query

**WebFetchTool:**
- `url` - The URL to fetch

**MarkdownNewTool:**
- `url` - The URL to convert to markdown

## Examples

### Example 1: Auto-approve read-only file operations

```json
{
  "SafeFileAccess": {
    "value": "You are a helpful assistant with read-only file access.",
    "tools.FileSystemTool.operation": "read_file|list_dir",
    "tools.FileSystemTool.path": ".*"
  }
}
```

This configuration auto-approves:
- Any `read_file` or `list_dir` operations
- On any path

### Example 2: Auto-approve specific directory access

```json
{
  "ProjectAccess": {
    "value": "You are a helpful assistant with access to the project directory.",
    "tools.FileSystemTool.operation": "read_file|list_dir",
    "tools.FileSystemTool.path": "c:\\\\Users\\\\ypyl\\\\projects\\\\.*"
  }
}
```

This configuration auto-approves:
- Only `read_file` or `list_dir` operations
- Only for paths under `c:\Users\ypyl\projects\`

### Example 3: Auto-approve web operations

```json
{
  "WebResearch": {
    "value": "You are a research assistant with web access.",
    "tools.WebSearchTool.query": ".*",
    "tools.WebFetchTool.url": "https://.*",
    "tools.MarkdownNewTool.url": "https://.*"
  }
}
```

This configuration auto-approves:
- Any web search query
- Only HTTPS URLs for fetching and markdown conversion

### Example 4: Auto-approve safe PowerShell commands

```json
{
  "SafeCommands": {
    "value": "You are a helpful assistant with limited PowerShell access.",
    "tools.PowerShellTool.script": "^(Get-|Test-|Select-|Where-|Format-).*",
    "tools.PowerShellTool.working_directory": ".*"
  }
}
```

This configuration auto-approves:
- Only PowerShell commands starting with Get-, Test-, Select-, Where-, or Format-
- In any working directory

## How It Works

1. When the LLM requests a tool call, the system checks if auto-approval patterns are defined for the current system prompt
2. For each tool call, all defined patterns for that tool must match the corresponding parameters
3. If all patterns match, the tool is executed automatically without user confirmation
4. If any pattern doesn't match, the system falls back to manual approval (tool_pending state)

## Security Considerations

- **Be careful with write operations**: Avoid auto-approving `write_file` or destructive PowerShell commands
- **Use specific patterns**: Narrow patterns are safer than `.*` wildcards
- **Test patterns carefully**: Verify your regex patterns match only intended operations
- **Review logs**: Monitor what tools are being auto-executed

## Disabling Auto-Approval

To disable auto-approval for a system prompt, simply remove all `tools.*` keys from the configuration. The system will fall back to requiring manual confirmation for all tool calls.
